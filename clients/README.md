# Client read protocol

Clients read the ETag-aware publication pointer, then verify the immutable manifest and content-addressed component before switching the local cache.

CLI interval-triggered online checks wait a uniform 0–60 seconds when caller deadlines allow, and the next allowed check is the last successful check + 10 minutes + an independent uniform 0–60 seconds; first checks, explicit syncs and offline/cache reads have no pre-check delay. / CLI 按间隔触发的在线检查在调用方截止时间允许时均匀随机等待 0–60 秒，下次允许检查的时间为上次成功检查 + 10 分钟 + 独立均匀随机的 0–60 秒；首次检查、显式同步和离线/缓存读取不增加检查前等待。
