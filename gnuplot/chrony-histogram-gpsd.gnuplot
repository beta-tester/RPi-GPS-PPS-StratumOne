width = 1e-4

fn(x,w) = w * floor(x / w) + w / 2.0

set title "Histogram GPSD"
set xlabel "Offset"
set ylabel "Count"
set xtic format "%.0s %cs"  rotate by -45
set boxwidth width
set style fill solid


plot "<grep GPSD /var/log/chrony/refclocks.log"  using (fn((strcol(6) eq '-' ? 0.0 : $7),width)):(strcol(6) eq '-' ? 0.0 : 1.0)  smooth freq  with boxes  lc rgb "#008000"  notitle


# loop
pause 600
reread
