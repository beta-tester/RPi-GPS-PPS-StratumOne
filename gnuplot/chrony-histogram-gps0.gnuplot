width = 1e-4

fn(x,w) = w * floor(x / w) + w / 2.0

print "########################################"
stats "<grep GPS0 /var/log/chrony/refclocks.log" using 7 prefix "A"
print "########################################"
print sprintf("GPS0:\nmean:        %e => offset %e\nlo_quartile: %e\nmedian:      %e => offset %e\nup_quartile: %e", A_mean, -A_mean, A_lo_quartile, A_median, -A_median, A_up_quartile)
print "########################################"


set title "Histogram GPS0"
set xlabel "Offset"
set ylabel "Count"
set xtic format "%.0s %cs"  rotate by -45
set boxwidth width
set style fill solid


set arrow 1 from A_lo_quartile, graph  0.20 to A_lo_quartile, graph 0 front nohead
set arrow 2 from A_median,      graph  0.25 to A_median,      graph 0 front fill
set arrow 3 from A_up_quartile, graph  0.20 to A_up_quartile, graph 0 front nohead
set arrow 4 from A_mean,        graph -0.05 to A_mean,        graph 0 front fill

set label 1 at graph 0, graph 1-0.125*0 sprintf("GPS0:\nmean: %e (%.1f ms)\nmedian: %e (%.1f ms)", A_mean, A_mean*1000.0, A_median, A_median*1000.0) left offset graph 0.05, graph -0.05 front


plot "<grep GPS0 /var/log/chrony/refclocks.log"  using (fn((strcol(6) eq '-' ? 0.0 : $7),width)):(strcol(6) eq '-' ? 0.0 : 1.0)  smooth freq  with boxes  lc rgb "#008000"  notitle


# loop
pause 600
reread
