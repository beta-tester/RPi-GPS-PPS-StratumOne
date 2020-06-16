set yrange [-1e-4:1e-4]

# setup
set title "Refclock Log"
set xlabel "Timestamp (UTC)"
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set xtic   format "%Y-%m-%dT%H:%M:%S"  rotate by -45
set ytics  format "%.1s%cs"
set y2tics textcolor rgb "#008000"  format "%.1s%cs"
set key center bottom opaque
set lmargin 12
set rmargin 12
set grid

# plot
plot \
"<grep GPS0 /var/log/chrony/refclocks.log"  using 1:7  title "GPS0"  with points  axis x1y2  pt 1  ps 0.3  lc "#008000", \
"<grep PSM0 /var/log/chrony/refclocks.log"  using 1:7  title "PSM0"  with points  axis x1y1  pt 1  ps 0.3  lc "#800080", \
"<grep PPS0 /var/log/chrony/refclocks.log"  using 1:7  title "PPS0"  with points  axis x1y1  pt 1  ps 0.3  lc "#808000"

# loop
pause 60
reread
