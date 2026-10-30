// SPDX-License-Identifier: MIT
package appserver

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// Handler is the extension seam for refresh/plugin and cockpit/history units.
// The core reserves query result space before calling a handler. Private output
// must carry the admission stamp/scopes; a stale result becomes consent_changed.
type Handler struct {
	Timeout    time.Duration
	Capability string
	Query      bool
	Private    bool
	Handle     func(context.Context, json.RawMessage, Stamp) (Reply, error)
}

type Reply struct {
	// Receipt preserves a completed mutation result even after cancellation.
	Receipt   bool
	subscribe bool
	Stamp     Stamp
	Scopes    []string
	Data      any
}

type Config struct {
	Version  string
	Backend  Backend
	Handlers map[string]Handler
	// Shorter durations are for synthetic transport tests; zero uses wire limits.
	WriteTimeout   time.Duration
	RequestTimeout time.Duration
}

type activeRequest struct{ cancel context.CancelFunc }

type Server struct {
	clientCapabilities                              map[string]bool
	refreshWake                                     chan struct{}
	config                                          Config
	backend                                         Backend
	mu                                              sync.Mutex
	refreshMu                                       sync.Mutex
	initialized, initializing, subscribed, stopping bool
	session                                         string
	view                                            View
	sequence                                        uint64
	active                                          map[string]activeRequest
	normal, queries, controls                       int
	out                                             *outbound
	ctx                                             context.Context
	stop                                            context.CancelFunc
	started                                         time.Time
	credentials                                     map[string]*credentialOperation
}

func New(config Config) *Server {
	if config.Backend == nil {
		config.Backend = UnavailableBackend{}
	}
	if config.Version == "" {
		config.Version = "0.1.0-dev"
	}
	if config.WriteTimeout <= 0 {
		config.WriteTimeout = wire.WriteTimeout
	}
	if config.RequestTimeout <= 0 {
		config.RequestTimeout = wire.RequestTimeout
	}
	return &Server{refreshWake: make(chan struct{}, 1), config: config, backend: config.Backend, active: map[string]activeRequest{}, credentials: map[string]*credentialOperation{}}
}

// Serve owns and closes its two anonymous pipes. Only the outbound goroutine
// writes stdout. EOF/cancel closes both pipes and interrupts blocked writes.
func (s *Server) Serve(ctx context.Context, in io.ReadCloser, out io.WriteCloser) error {
	defer in.Close()
	defer out.Close()
	if file, ok := in.(*os.File); ok {
		pipe, err := cancellablePipe(file)
		if err != nil {
			return err
		}
		in = pipe
	}
	if file, ok := out.(*os.File); ok {
		pipe, err := cancellablePipe(file)
		if err != nil {
			_ = in.Close()
			return err
		}
		out = pipe
	}

	s.ctx, s.stop = context.WithCancel(ctx)
	s.started = time.Now()
	defer s.stop()
	s.out = newOutbound(s.ctx, s.stop, out, s.config.WriteTimeout, s.mayEmit)
	writerDone := make(chan struct{})
	go s.out.run(writerDone)
	closerDone := make(chan struct{})
	go func() { defer close(closerDone); <-s.ctx.Done(); _ = in.Close(); _ = out.Close() }()
	frames := make(chan []byte)
	readDone := make(chan struct{})
	go func() {
		defer close(readDone)
		defer close(frames)
		reader := bufio.NewReaderSize(in, 32<<10)
		for {
			frame, err := readFrame(reader)
			if err != nil {
				return
			}
			select {
			case frames <- frame:
			case <-s.ctx.Done():
				return
			}
		}
	}()
	go func() {
		for {
			select {
			case <-s.ctx.Done():
				return
			case <-s.refreshWake:
				ctx, cancel := context.WithTimeout(s.ctx, s.config.RequestTimeout)
				_ = s.refresh(ctx)
				cancel()
			}
		}
	}()
	changes := s.backend.Changes(s.ctx)
	for {
		select {
		case <-s.ctx.Done():
			s.cancelAll()
			<-closerDone
			<-writerDone
			<-readDone
			return nil
		case frame, ok := <-frames:
			if !ok {
				s.stop()
				continue
			}
			request, err := decodeRequest(frame)
			if err != nil {
				s.stop()
				continue
			}
			s.dispatch(request)
		case _, ok := <-changes:
			if !ok {
				changes = nil
				continue
			}
			// One refresh at a time; bursts coalesce without blocking command admission.
			s.mu.Lock()
			ready := s.initialized
			s.mu.Unlock()
			if ready {
				s.scheduleRefresh()
			}
		}
	}
}

func (s *Server) cancelAll() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, a := range s.active {
		a.cancel()
	}
	for key, op := range s.credentials {
		op.timer.Stop()
		op.reject()
		delete(s.credentials, key)
	}
}
func (s *Server) isCurrent(stamp Stamp) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.initialized && stamp == s.view.Stamp
}

// Check the shared store immediately before writing as well as at enqueue, so
// an external revoke need not wait for its filesystem watcher to drain data.
func (s *Server) mayEmit(stamp Stamp) bool {
	ctx, cancel := context.WithTimeout(s.ctx, s.config.WriteTimeout)
	defer cancel()
	if err := s.backend.Publish(ctx, stamp, func() error { return nil }); err != nil {
		s.scheduleRefresh()
		return false
	}
	return s.isCurrent(stamp)
}
func (s *Server) currentStamp() Stamp { s.mu.Lock(); defer s.mu.Unlock(); return s.view.Stamp }
func (s *Server) errorMessage(id wire.ID, code int) wire.Failure {
	s.mu.Lock()
	defer s.mu.Unlock()
	info := wire.ErrorContext{SessionID: s.session}
	if s.initialized {
		epoch, gen := s.view.Stamp.Epoch, s.view.Stamp.Generation
		info.StoreEpoch = &epoch
		info.ConsentGeneration = &gen
	}
	if len(id) == 0 {
		id = wire.ID(`null`)
	}
	return wire.Failure{JSONRPC: wire.JSONRPC, ID: id, Error: wire.RPCError{Code: code, Message: wire.ErrorName(code), Data: info}}
}
func (s *Server) sendError(id wire.ID, code int) { s.out.controlMessage(s.errorMessage(id, code)) }
func envelope[T any](session string, stamp Stamp, scopes []string, data T) wire.Envelope[T] {
	return wire.Envelope[T]{SessionID: session, StoreEpoch: stamp.Epoch, ConsentGeneration: stamp.Generation, Scopes: scopes, Data: data}
}
func success(session string, id wire.ID, stamp Stamp, scopes []string, data any) wire.Success[any] {
	return wire.Success[any]{JSONRPC: wire.JSONRPC, ID: id, Result: envelope(session, stamp, scopes, data)}
}
func notification(session, method string, stamp Stamp, scopes []string, data any) wire.Notification[any] {
	return wire.Notification[any]{JSONRPC: wire.JSONRPC, Method: method, Params: envelope(session, stamp, scopes, data)}
}

func (s *Server) dispatch(r wire.Request) {
	if r.Method == "$/cancel" {
		p, err := params[wire.CancelParams](r.Params)
		if err != nil || !validID(p.ID) {
			if len(r.ID) > 0 {
				s.sendError(r.ID, wire.CodeInvalidParams)
			}
			return
		}
		s.mu.Lock()
		a, ok := s.active[requestKey(p.ID)]
		s.mu.Unlock()
		if ok {
			a.cancel()
		}
		return
	}
	if len(r.ID) == 0 {
		return
	} // mutations require a request/receipt, never a notification
	if r.Method == "initialize" {
		s.initialize(r)
		return
	}
	s.mu.Lock()
	ready, stopping := s.initialized, s.stopping
	s.mu.Unlock()
	if !ready {
		s.sendError(r.ID, wire.CodeNotInitialized)
		return
	}
	if stopping {
		s.sendError(r.ID, wire.CodeCanceled)
		return
	}
	if r.Method == "shutdown" {
		if _, err := params[wire.Empty](r.Params); err != nil {
			s.sendError(r.ID, wire.CodeInvalidParams)
			return
		}
		s.mu.Lock()
		s.stopping = true
		session, stamp := s.session, s.view.Stamp
		s.mu.Unlock()
		s.cancelAll()
		s.out.controlThen(success(session, r.ID, stamp, nil, wire.Empty{}), s.stop)
		return
	}
	if r.Method == "consent/grant" {
		p, err := params[wire.ConsentGrantParams](r.Params)
		if err != nil || !validGrant(p) {
			s.sendError(r.ID, wire.CodeInvalidParams)
			return
		}
		control := len(p.Deny) > 0 || len(p.Forget) > 0
		s.start(r, false, control, false, func(ctx context.Context) (Reply, error) {
			result, err := s.backend.Grant(ctx, p)
			if err != nil && !result.Receipt.Committed {
				stamp := result.Stamp
				if stamp.Epoch == "" {
					if view, getErr := s.backend.Get(ctx); getErr == nil {
						stamp = view.Stamp
					}
				}
				return Reply{}, responseContextError{err: err, stamp: stamp}
			}
			// Even a canceled request returns a committed receipt, including cleanup.
			reply := Reply{Stamp: result.Stamp, Data: result.Receipt}
			s.scheduleRefresh()
			for _, need := range result.Credentials {
				if need.Interactive && p.Keychain[need.Scope] != wire.KeychainAllow {
					continue
				}
				_, _ = s.requestCredential(need, true)
			}
			return reply, nil
		})
		return
	}
	if r.Method == "credentials/result" {
		p, err := credentialParams(r.Params)
		if err != nil {
			s.sendError(r.ID, wire.CodeCredentialRejected)
			return
		}
		s.start(r, false, true, false, func(ctx context.Context) (Reply, error) {
			err := s.acceptCredential(ctx, p)
			p.AccessToken = nil
			return Reply{Stamp: s.currentStamp(), Data: wire.Empty{}}, err
		})
		return
	}
	switch r.Method {
	case "rows/subscribe":
		if _, err := params[wire.Empty](r.Params); err != nil {
			s.sendError(r.ID, wire.CodeInvalidParams)
			return
		}
		s.start(r, false, false, true, func(ctx context.Context) (Reply, error) {
			if err := s.refresh(ctx); err != nil {
				return Reply{}, err
			}
			return Reply{Stamp: s.currentStamp(), subscribe: true}, nil
		})
		return

	case "consent/get":
		if _, err := params[wire.Empty](r.Params); err != nil {
			s.sendError(r.ID, wire.CodeInvalidParams)
			return
		}
		s.start(r, false, false, false, func(ctx context.Context) (Reply, error) {
			if err := s.refresh(ctx); err != nil {
				return Reply{}, err
			}
			s.mu.Lock()
			v := s.view
			s.mu.Unlock()
			return Reply{Stamp: v.Stamp, Data: v.Consent}, nil
		})
		return
	case "diagnostics/get":
		if _, err := params[wire.Empty](r.Params); err != nil {
			s.sendError(r.ID, wire.CodeInvalidParams)
			return
		}
		s.start(r, false, false, false, func(context.Context) (Reply, error) {
			s.mu.Lock()
			v := s.view
			s.mu.Unlock()
			return Reply{Stamp: v.Stamp, Data: wire.Diagnostics{ProtocolVersion: wire.ProtocolVersion, ServerVersion: s.config.Version, UptimeSeconds: int64(time.Since(s.started).Seconds()), Scopes: v.Diagnostics}}, nil
		})
		return
	}
	handler, ok := s.config.Handlers[r.Method]
	if !ok || handler.Handle == nil {
		s.sendError(r.ID, wire.CodeMethodNotFound)
		return
	}
	s.startPolicy(r, handler.Query, false, true, handler.Private, handler.Timeout, func(ctx context.Context) (Reply, error) {
		stamp := s.currentStamp()
		reply, err := handler.Handle(ctx, r.Params, stamp)
		if err != nil {
			return Reply{}, err
		}
		if handler.Private && (!s.isCurrent(stamp) || reply.Stamp != stamp || len(reply.Scopes) == 0) {
			return Reply{}, ProtocolError{wire.CodeConsentChanged}
		}

		if !handler.Private {
			reply.Stamp = s.currentStamp()
			reply.Scopes = nil
		}
		return reply, nil
	})
}

func validGrant(p wire.ConsentGrantParams) bool {
	if p.RequestID == "" || p.ExpectStoreEpoch == "" || p.TextVersion <= 0 || p.Allow == nil || p.Deny == nil {
		return false
	}
	for _, choice := range p.Keychain {
		if choice != wire.KeychainAllow && choice != wire.KeychainDeny {
			return false
		}
	}
	return true
}

func (s *Server) start(r wire.Request, query, control, data bool, run func(context.Context) (Reply, error)) {
	s.startPolicy(r, query, control, data, data, 0, run)
}
func (s *Server) startPolicy(r wire.Request, query, control, data, private bool, timeout time.Duration, run func(context.Context) (Reply, error)) {
	if timeout <= 0 {
		timeout = s.config.RequestTimeout
	}
	if timeout > wire.PluginInstallTimeout {
		timeout = wire.PluginInstallTimeout
	}

	key := requestKey(r.ID)
	s.mu.Lock()
	if _, exists := s.active[key]; exists {
		s.mu.Unlock()
		s.sendError(r.ID, wire.CodeInvalidRequest)
		return
	}
	if control {
		if s.controls >= wire.MaxControlMessages {
			s.mu.Unlock()
			s.stop()
			return
		}
	} else if s.normal >= wire.MaxRequests || query && s.queries >= wire.MaxQueries {
		s.mu.Unlock()
		s.sendError(r.ID, wire.CodeBusy)
		return
	}
	if data && !s.out.reserve() {
		s.mu.Unlock()
		s.sendError(r.ID, wire.CodeBusy)
		return
	}
	ctx, cancel := context.WithTimeout(context.WithValue(s.ctx, sessionContextKey{}, s.session), timeout)
	s.active[key] = activeRequest{cancel: cancel}
	if control {
		s.controls++
	} else {
		s.normal++
	}
	if query {
		s.queries++
	}
	session := s.session
	s.mu.Unlock()
	go func() {
		defer cancel()
		reply, err := run(ctx)
		s.mu.Lock()
		delete(s.active, key)
		if control {
			s.controls--
		} else {
			s.normal--
		}
		if query {
			s.queries--
		}
		s.mu.Unlock()
		if s.ctx.Err() != nil {
			if data {
				s.out.release()
			}
			return
		}
		// A committed receipt wins over cancellation after the transaction.
		_, receipt := reply.Data.(wire.ConsentReceipt)
		if err == nil && ctx.Err() != nil && !receipt && !reply.Receipt {
			err = ctx.Err()
		}
		if err != nil {
			if data {
				s.out.release()
			}
			message := s.errorMessage(r.ID, errorCode(err))
			var authoritative responseContextError
			if errors.As(err, &authoritative) {
				message.Error.Data.StoreEpoch, message.Error.Data.ConsentGeneration = nil, nil
				if authoritative.stamp.Epoch != "" {
					message.Error.Data.StoreEpoch = &authoritative.stamp.Epoch
					message.Error.Data.ConsentGeneration = &authoritative.stamp.Generation
				}
			}
			s.out.controlMessage(message)
			return
		}

		if data && !private {
			s.out.dataMessage(success(session, r.ID, reply.Stamp, nil, reply.Data), reply.Stamp, false, nil)
			return
		}
		if data {
			err := s.backend.Publish(ctx, reply.Stamp, func() error {
				s.mu.Lock()
				defer s.mu.Unlock()
				if s.view.Stamp != reply.Stamp {
					return ProtocolError{wire.CodeConsentChanged}
				}
				if reply.subscribe {
					s.subscribed = true
					reply.Scopes = s.view.Scopes
					reply.Data = wire.RowsSnapshot{Sequence: s.sequence, Projection: wire.Project(s.view.Projection)}
				}
				s.out.dataMessage(success(session, r.ID, reply.Stamp, reply.Scopes, reply.Data), reply.Stamp, true, func() { s.sendError(r.ID, wire.CodeConsentChanged) })
				return nil
			})
			if err != nil {
				s.out.release()
				_ = s.refresh(ctx)
				s.sendError(r.ID, errorCode(err))
			}
		} else {
			s.out.controlMessage(success(session, r.ID, reply.Stamp, reply.Scopes, reply.Data))
		}

	}()
}

func (s *Server) initialize(r wire.Request) {
	p, err := params[wire.InitializeParams](r.Params)
	if err != nil || !validSession(p.SessionID) || p.AppVersion == "" || p.Capabilities == nil {
		s.sendError(r.ID, wire.CodeInvalidParams)
		return
	}
	major, minor, ok := strings.Cut(p.ProtocolVersion, ".")
	_, minorErr := strconv.ParseUint(minor, 10, 32)
	if !ok || minorErr != nil {
		s.sendError(r.ID, wire.CodeInvalidParams)
		return
	}
	s.mu.Lock()
	if s.initialized || s.initializing {
		same := p.SessionID == s.session
		s.mu.Unlock()
		if !same {
			s.sendError(r.ID, wire.CodeWrongSession)
		} else {
			s.sendError(r.ID, wire.CodeInvalidRequest)
		}
		return
	}
	s.session = p.SessionID
	s.clientCapabilities = map[string]bool{}
	for _, capability := range p.Capabilities {
		s.clientCapabilities[capability] = true
	}
	s.initializing = true
	s.mu.Unlock()
	if major != "1" {
		s.out.controlThen(s.errorMessage(r.ID, wire.CodeProtocolMismatch), s.stop)
		return
	}
	ctx, cancel := context.WithTimeout(s.ctx, s.config.RequestTimeout)
	go func() {
		defer cancel()
		s.refreshMu.Lock()
		v, err := s.backend.Get(ctx)
		s.refreshMu.Unlock()
		s.mu.Lock()
		s.initializing = false
		if err == nil && validView(v) {
			s.view = v
			s.sequence = 1
			s.initialized = true
		} else if err == nil {
			err = ProtocolError{wire.CodeInternal}
		}
		s.mu.Unlock()
		if err != nil {
			s.sendError(r.ID, errorCode(err))
			return
		}
		caps := s.capabilities()
		s.out.controlMessage(success(p.SessionID, r.ID, v.Stamp, nil, wire.InitializeResult{ProtocolVersion: wire.ProtocolVersion, ServerVersion: s.config.Version, Capabilities: caps}))
		s.out.controlMessage(notification(p.SessionID, "engine/health", v.Stamp, nil, v.Health))
	}()
}
func validSession(id string) bool {
	if len(id) == 0 || len(id) > 128 {
		return false
	}
	for _, c := range id {
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.ContainsRune("._-", c) {
			continue
		}
		return false
	}
	return true
}
func validView(v View) bool {
	return v.Stamp.Epoch != "" && v.Projection.ConsentGeneration == v.Stamp.Generation && v.Projection.Rows != nil && v.Consent.Scopes != nil && v.Diagnostics != nil
}
func (s *Server) capabilities() []string {
	supported := []string{"rows", "consent", "credentials", "diagnostics"}
	if c, ok := s.backend.(Capabilities); ok {
		supported = c.Capabilities()
	}
	for _, handler := range s.config.Handlers {
		if handler.Capability != "" {
			supported = append(supported, handler.Capability)
		}
	}
	allowed := map[string]bool{}
	for _, cap := range supported {
		allowed[cap] = true
	}
	result := []string{}
	seen := map[string]bool{}
	for _, cap := range supported {
		if allowed[cap] && !seen[cap] {
			result = append(result, cap)
			seen[cap] = true
		}
	}
	sort.Strings(result)
	return result
}

// refreshRunning coalesces backend change bursts. refreshMu serializes snapshots
// so an earlier backend read cannot overwrite a later generation.
func (s *Server) scheduleRefresh() {
	select {
	case s.refreshWake <- struct{}{}:
	default:
	}
}
func (s *Server) refresh(ctx context.Context) error {
	s.refreshMu.Lock()
	defer s.refreshMu.Unlock()
	return s.readView(ctx)
}
func (s *Server) readView(ctx context.Context) error {
	v, err := s.backend.Get(ctx)
	if err != nil {
		return err
	}
	if !validView(v) {
		return ProtocolError{wire.CodeInternal}
	}
	s.mu.Lock()
	if !s.initialized {
		s.mu.Unlock()
		return nil
	}
	old := s.view
	if v.Stamp.Epoch == old.Stamp.Epoch && v.Stamp.Generation < old.Stamp.Generation {
		s.mu.Unlock()
		return ProtocolError{wire.CodeConsentChanged}
	}
	if reflect.DeepEqual(old, v) {
		s.mu.Unlock()
		return nil
	}
	s.view = v
	s.sequence++
	session, seq, subscribed := s.session, s.sequence, s.subscribed
	for key, op := range s.credentials {
		if op.stamp != v.Stamp {
			op.timer.Stop()
			op.reject()
			delete(s.credentials, key)
		}
	}
	s.mu.Unlock()
	if old.Stamp != v.Stamp || !reflect.DeepEqual(old.Consent, v.Consent) {
		s.out.controlMessage(notification(session, "consent/changed", v.Stamp, nil, v.Consent))
	}
	if old.Health != v.Health {
		s.out.controlMessage(notification(session, "engine/health", v.Stamp, nil, v.Health))
	}
	if subscribed {
		if err := s.backend.Publish(ctx, v.Stamp, func() error {
			s.out.rowsMessage(notification(session, "rows/changed", v.Stamp, v.Scopes, wire.RowsSnapshot{Sequence: seq, Projection: wire.Project(v.Projection)}), v.Stamp)
			return nil
		}); err != nil {
			s.scheduleRefresh()
			return err
		}
	}
	return nil
}
