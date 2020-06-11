# setup
set title "Tempcomp Log"
set xlabel "Timestamp (UTC)"
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set format x "%Y-%m-%dT%H:%M:%S"timedate
set xtic   rotate by -45
set ytics  textcolor rgb "#800000"  format "%.1s %c°C"
set y2tics textcolor rgb "#008000"  format "%.1f ppm"
set key center bottom  opaque
set lmargin 12
set rmargin 12
set grid

# plot
plot \
"/var/log/chrony/tracking.log"  using 1:5          title "Freq ppm"  with lines   axis x1y2  lc rgb "#008000", \
"/var/log/chrony/tempcomp.log"  using 1:($3/1000)  title "CPU Temp"  with lines   axis x1y1  lc rgb "#800000"

# loop
pause 60
reread
