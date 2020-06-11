set yrange [-1e-5:1e-5]

# setup
set title "Tracking Log"
set xlabel "Timestamp (UTC)"
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set format x "%Y-%m-%dT%H:%M:%S"timedate
set xtic   rotate by -45
set ytics  textcolor rgb "#800080"  format "%.1s %cs"
set y2tics textcolor rgb "#008000"  format "%.1f ppm"
set key center bottom  opaque
set lmargin 12
set rmargin 12
set grid

# plot
plot \
"/var/log/chrony/tracking.log"  using 1:7  title "Offset"    with points  axis x1y1  lc rgb "#800080"  ps 0.3, \
""                              using 1:5  title "Freq ppm"  with lines   axis x1y2  lc rgb "#008000"

# loop
pause 60
reread
