# bthread
Usage:

bthread "command1" "command2" "..."

All the commands will be run in parallel and output given after all of them complete.


### Proof of concept



        netikras@netikras-xps ~/workspace2/bthread $ time ./bthread "sar -u 1 4" "sar -d 1 4" uptime "sar -q 1 4"
        STARTING THREAD: [sar -u 1 4]
        STARTING THREAD: [sar -d 1 4]
        STARTING THREAD: [uptime]
        STARTING THREAD: [sar -q 1 4]
        
        ==============================
        
        Thread ID:      [4]
        Thread[4] TID: [19010]
        Thread[4] CMD: [sar -u 1 4]
        Thread[4] OUT: [/proc/19004/fd/4]
        Linux 4.10.0-38-generic (netikras-xps) 	2018.03.04 	_x86_64_	(4 CPU)
        
        17:35:53        CPU     %user     %nice   %system   %iowait    %steal     %idle
        17:35:54        all      7,12      0,00      1,27      0,00      0,00     91,60
        17:35:55        all      4,80      0,00      1,26      0,51      0,00     93,43
        17:35:56        all      5,04      0,00      1,26      0,25      0,00     93,45
        17:35:57        all      5,53      0,00      1,76      1,51      0,00     91,21
        Average:        all      5,62      0,00      1,39      0,57      0,00     92,42
        ============[EOT]===========
        
        Thread ID:      [5]
        Thread[5] TID: [19018]
        Thread[5] CMD: [sar -d 1 4]
        Thread[5] OUT: [/proc/19004/fd/5]
        Linux 4.10.0-38-generic (netikras-xps) 	2018.03.04 	_x86_64_	(4 CPU)
        
        17:35:53          DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz     await     svctm     %util
        17:35:54     dev259-0      1,00      0,00      8,00      8,00      0,00      4,00      4,00      0,40
        
        17:35:54          DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz     await     svctm     %util
        17:35:55     dev259-0      0,00      0,00      0,00      0,00      0,00      0,00      0,00      0,00
        
        17:35:55          DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz     await     svctm     %util
        17:35:56     dev259-0      0,00      0,00      0,00      0,00      0,00      0,00      0,00      0,00
        
        17:35:56          DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz     await     svctm     %util
        17:35:57     dev259-0      3,00      0,00    136,00     45,33      0,04     13,33     13,33      4,00
        
        Average:          DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz     await     svctm     %util
        Average:     dev259-0      1,00      0,00     36,00     36,00      0,01     11,00     11,00      1,10
        ============[EOT]===========
        
        Thread ID:      [6]
        Thread[6] TID: [19026]
        Thread[6] CMD: [uptime]
        Thread[6] OUT: [/proc/19004/fd/6]
         17:35:53 up 1 day, 22:47, 14 users,  load average: 0,39, 0,28, 0,31
        ============[EOT]===========
        
        Thread ID:      [7]
        Thread[7] TID: [19033]
        Thread[7] CMD: [sar -q 1 4]
        Thread[7] OUT: [/proc/19004/fd/7]
        Linux 4.10.0-38-generic (netikras-xps) 	2018.03.04 	_x86_64_	(4 CPU)
        
        17:35:53      runq-sz  plist-sz   ldavg-1   ldavg-5  ldavg-15   blocked
        17:35:54            0       963      0,39      0,28      0,31         0
        17:35:55            0       963      0,39      0,28      0,31         0
        17:35:56            2       963      0,36      0,28      0,31         1
        17:35:57            0       957      0,36      0,28      0,31         0
        Average:            0       962      0,38      0,28      0,31         0
        ============[EOT]===========
        
        
        
        real    0m4.182s
        user    0m0.008s
        sys     0m0.016s
        netikras@netikras-xps ~/workspace2/bthread $ 


Notice the commands launched and total time spent.
