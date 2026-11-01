// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestActivityObserverNotifiesOnTransitionAndExpiry(t *testing.T) {
	t.Setenv("HOME",t.TempDir())
	t.Setenv("MODELPLAN_READERS","")
	ctx,cancel:=context.WithCancel(context.Background());defer cancel()
	phase:=make(chan string,3);phase<-"tool";phase<-"tool";phase<-"finished"
	at:=time.Now().UTC();b:=&SharedBackend{changes:make(chan struct{},1)}
	b.config.Activity=func(context.Context,consent.Admission,time.Time)[]rows.ActivityInput{return []rows.ActivityInput{{ToolID:"codex",SubscriptionRef:"aaaaaaaaaaaaaaaa",SessionRef:"bbbbbbbbbbbbbbbb",BindingVerified:true,Phase:rows.ActivityPhase(<-phase),RecordAt:at,ExpiresAt:at.Add(5*time.Minute)}}}
	b.observeActivity(ctx,at)
	select{case <-b.changes:default:t.Fatal("transition not notified")}
	b.observeActivity(ctx,at)
	select{case <-b.changes:t.Fatal("unchanged verdict notified");default:}
	b.observeActivity(ctx,at.Add(5*time.Minute))
	select{case <-b.changes:default:t.Fatal("expiry not notified")}
}

func TestActivityContextChangeDoesNotPublishOldBinding(t *testing.T) {
	b:=&SharedBackend{activityStamp:Stamp{Epoch:"old",Generation:1},activity:[]rows.ActivityInput{{SessionRef:"aaaaaaaaaaaaaaaa"}}}
	if got:=b.activityFor(Stamp{Epoch:"new",Generation:1});len(got)!=0{t.Fatal("cross-epoch activity")}
	if got:=b.activityFor(Stamp{Epoch:"old",Generation:2});len(got)!=0{t.Fatal("revoked-generation activity")}
}
