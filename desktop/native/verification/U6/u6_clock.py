# SPDX-License-Identifier: MIT
"""Mac system-uptime clock, with monotonic fallback for offline replay hosts."""
import time

def system_uptime(clock=time):
    raw=getattr(clock,'CLOCK_UPTIME_RAW',None)
    return clock.clock_gettime(raw) if raw is not None else clock.monotonic()
