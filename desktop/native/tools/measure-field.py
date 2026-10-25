#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import pathlib,subprocess,time,ctypes,json,os,hashlib,argparse,shutil
parser=argparse.ArgumentParser(description='B05a own-app + positively associated WebKit resource proof')
parser.add_argument('app');parser.add_argument('resources');parser.add_argument('output')
args=parser.parse_args()
root=pathlib.Path(args.output).resolve();root.mkdir(parents=True,exist_ok=False)
app=pathlib.Path(args.app).resolve();exe=app/'Contents/MacOS/ModelPlanFieldProbe'
resources=pathlib.Path(args.resources).resolve()
class Usage(ctypes.Structure):
 _fields_=[('uuid',ctypes.c_ubyte*16)]+[(n,ctypes.c_uint64) for n in ('user','system','idle','interrupt','pageins','wired','rss','footprint','birth','exit')]
class TB(ctypes.Structure):_fields_=[('numer',ctypes.c_uint32),('denom',ctypes.c_uint32)]
lib=ctypes.CDLL('/usr/lib/libSystem.B.dylib',use_errno=True);lib.proc_pid_rusage.argtypes=[ctypes.c_int,ctypes.c_int,ctypes.c_void_p]
tb=TB();lib.mach_timebase_info(ctypes.byref(tb))
def usage(pid):
 u=Usage()
 if lib.proc_pid_rusage(pid,0,ctypes.byref(u)):return None
 return {'pid':pid,'birth':u.birth,'bytes':u.footprint,'cpuNs':(u.user+u.system)*tb.numer/tb.denom}
def helpers():
 x=subprocess.check_output(['ps','-axo','pid,comm'],text=True)
 return {int(line.split()[0]):line.split()[-1] for line in x.splitlines() if '/com.apple.WebKit.' in line}

lib.responsibility_get_pid_responsible_for_pid.argtypes=[ctypes.c_int];lib.responsibility_get_pid_responsible_for_pid.restype=ctypes.c_int
known={};rows=[]

subprocess.run(['open','-n','-a',str(app),'--args','--resources',str(resources),'--output',str(root)],check=True)
pid=None
for _ in range(100):
 for line in subprocess.check_output(['ps','-axo','pid,command'],text=True).splitlines():
  parts=line.strip().split(None,1)
  if len(parts)==2 and parts[1].startswith(str(exe)+' --resources ') and '--output '+str(root) in parts[1]:pid=int(parts[0]);break
 if pid:break
 time.sleep(.1)
assert pid
class Running:
 def __init__(self,pid):self.pid=pid;self.initial=usage(pid)['birth']
 def poll(self):
  u=usage(self.pid);return None if u and u['birth']==self.initial else 0
 def terminate(self):
  if self.poll() is None:os.kill(self.pid,15)
 def wait(self,timeout=10):
  until=time.monotonic()+timeout
  while self.poll() is None and time.monotonic()<until:time.sleep(.1)
child=Running(pid)
idle=subprocess.Popen(['caffeinate','-d','-i','-t','1100','-w',str(child.pid)])
start=time.monotonic()
try:
 while child.poll() is None and time.monotonic()-start<1010:
  now=time.monotonic()-start
  if int(now)%3==0:
   known.update({p:n for p,n in helpers().items() if lib.responsibility_get_pid_responsible_for_pid(p)==child.pid})
  native=usage(child.pid);aux=[dict(u,kind=n.split('.')[-1]) for p,n in known.items() if (u:=usage(p)) is not None]
  rows.append({'seconds':now,'native':native,'helpers':aux,'aggregateBytes':native['bytes']+sum(v['bytes'] for v in aux)})
  (root/'samples.json').write_text(json.dumps({'schemaVersion':1,'nativePID':child.pid,'nativeResponsiblePID':lib.responsibility_get_pid_responsible_for_pid(child.pid),'helperAttribution':'responsibility_get_pid_responsible_for_pid equals the separately launched application PID','executableSHA256':hashlib.sha256(exe.read_bytes()).hexdigest(),'rows':rows}))
  time.sleep(1)
 if child.poll() is None:child.terminate()
 child.wait(timeout=10)
 (root/'run-events.json').write_bytes((root/'events.json').read_bytes())
 verify=root/'relaunch';verify.mkdir()
 if (root/'still.png').exists():shutil.copyfile(root/'still.png',verify/'still.png')
 subprocess.run([str(exe),'--resources',str(resources),'--output',str(verify),'--verify-still','yes'],timeout=20,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
finally:
 if child.poll() is None:child.terminate();child.wait(timeout=10)
 if idle.poll() is None:idle.terminate();idle.wait(timeout=10)
print('B05a probe exited; evaluate measured results and unconfirmed helper attribution',flush=True)
