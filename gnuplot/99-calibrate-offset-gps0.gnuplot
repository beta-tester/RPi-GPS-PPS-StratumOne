width = 1e-4

fn(x,w) = w * floor(x / w) + w / 2.0

set title "Calibration Offset GPS0"
set xlabel "Offset (for configuration file)"
set ylabel "Count"
set xtic format "%.3f"  rotate by -45
set boxwidth width
set style fill solid


plot "<grep GPS0 /var/log/chrony/refclocks.log"  using (-1 * fn((strcol(6) eq '-' ? 0.0 : $7),width)):(strcol(6) eq '-' ? 0.0 : 1.0)  smooth freq  with boxes  lc rgb "#008000"  notitle


# loop
pause 60
reread
