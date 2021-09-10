width = 1e-8
set xrange[-1e-5:1e-5]

fn(x,w) = w * floor(x / w) + w / 2.0

print "########################################"
stats "<grep PPS0 /var/log/chrony/refclocks.log" using 7 prefix "A"
#stats "<grep PSM0 /var/log/chrony/refclocks.log" using 7 prefix "B"
#stats "<grep PST0 /var/log/chrony/refclocks.log" using 7 prefix "C"
print "########################################"
print sprintf("PPS0:\nmean:        %e => offset %e\nlo_quartile: %e\nmedian:      %e => offset %e\nup_quartile: %e", A_mean, -A_mean, A_lo_quartile, A_median, -A_median, A_up_quartile)
#print sprintf("PSM0:\nmean:        %e => offset %e\nlo_quartile: %e\nmedian:      %e => offset %e\nup_quartile: %e", B_mean, -B_mean, B_lo_quartile, B_median, -B_median, B_up_quartile)
#print sprintf("PST0:\nmean:        %e => offset %e\nlo_quartile: %e\nmedian:      %e => offset %e\nup_quartile: %e", C_mean, -C_mean, C_lo_quartile, C_median, -C_median, C_up_quartile)
print "########################################"


set title "Histogram PPS0"
set xlabel "Offset"
set ylabel "Count"
set xtic format "%.0s %cs"  rotate by -45
set boxwidth width
set style fill solid


set arrow 1 from A_lo_quartile, graph  0.20 to A_lo_quartile, graph 0 front nohead
set arrow 2 from A_median,      graph  0.25 to A_median,      graph 0 front fill
set arrow 3 from A_up_quartile, graph  0.20 to A_up_quartile, graph 0 front nohead
set arrow 4 from A_mean,        graph -0.05 to A_mean,        graph 0 front fill

set label 1 at graph 0, graph 1-0.125*0 sprintf("PPS0:\nmean: %e (%.1f ns)\nmedian: %e (%.1f ns)", A_mean, A_mean*1000000000.0, A_median, A_median*1000000000.0) left offset graph 0.05, graph -0.05 front
#set label 2 at graph 0, graph 1-0.125*1 sprintf("PSM0:\nmean: %e (%.1f ns)\nmedian: %e (%.1f ns)", B_mean, B_mean*1000000000.0, B_median, B_median*1000000000.0) left offset graph 0.05, graph -0.05 front
#set label 3 at graph 0, graph 1-0.125*2 sprintf("PST0:\nmean: %e (%.1f ns)\nmedian: %e (%.1f ns)", C_mean, C_mean*1000000000.0, C_median, C_median*1000000000.0) left offset graph 0.05, graph -0.05 front


plot "<grep PPS0 /var/log/chrony/refclocks.log"  using (fn((strcol(6) eq '-' ? 0.0 : $7),width)):(strcol(6) eq '-' ? 0.0 : 1.0)  smooth freq  with boxes  lc rgb "#008000"  notitle

#plot "<grep PPS0 /var/log/chrony/refclocks.log"  using (fn((strcol(6) eq '-' ? 0.0 : $7),width)):(strcol(6) eq '-' ? 0.0 : 1.0)  smooth freq  with boxes  lc rgb "#800000"  notitle, \
#     "<grep PSM0 /var/log/chrony/refclocks.log"  using (fn((strcol(6) eq '-' ? 0.0 : $7),width)):(strcol(6) eq '-' ? 0.0 : 1.0)  smooth freq  with boxes  lc rgb "#808000"  notitle, \
#     "<grep PST0 /var/log/chrony/refclocks.log"  using (fn((strcol(6) eq '-' ? 0.0 : $7),width)):(strcol(6) eq '-' ? 0.0 : 1.0)  smooth freq  with boxes  lc rgb "#008000"  notitle


# loop
pause 600
reread
