#!/usr/bin/env python
# Filename:                check_pg_num.py
# Description:             python version of check_pg_num
# Supported Langauge(s):   Python 2.7.x
# Time-stamp:              <2018-02-15 11:11:05 fultonj> 
# -------------------------------------------------------
# Lumionus won't create pools unless it satisfies this check
#   http://bit.ly/2o6fOTO
# This is a conversion to Python as a leaning exercise and
# to review current defaults used by TripleO.
# -------------------------------------------------------
# The original check in C++ is:
# 
# int OSDMonitor::check_pg_num(int64_t pool, int pg_num, int size, ostream *ss)
# {
#   auto max_pgs_per_osd = g_conf->get_val<uint64_t>("mon_max_pg_per_osd");
#   auto num_osds = std::max(osdmap.get_num_in_osds(), 3u);   // assume min cluster size 3
#   auto max_pgs = max_pgs_per_osd * num_osds;
#   uint64_t projected = 0;
#   if (pool < 0) {
#     projected += pg_num * size;
#   }
#   for (const auto& i : osdmap.get_pools()) {
#     if (i.first == pool) {
#       projected += pg_num * size;
#     } else {
#       projected += i.second.get_pg_num() * i.second.get_size();
#     }
#   }
#   if (projected > max_pgs) {
#     if (pool >= 0) {
#       *ss << "pool id " << pool;
#     }
#     *ss << " pg_num " << pg_num << " size " << size
# 	<< " would mean " << projected
# 	<< " total pgs, which exceeds max " << max_pgs
# 	<< " (mon_max_pg_per_osd " << max_pgs_per_osd
# 	<< " * num_in_osds " << num_osds << ")";
#     return -ERANGE;
#   }
#   return 0;
# }
# -------------------------------------------------------

num_osds = 5
osp_pools = ['vms', 'volumes', 'images', 'backup', 'metrics', 'manila', 'manila_meta']
pg_num = 128
size = 3
max_pgs_per_osd = 600
pools = {}

def check_pg_num(pool, pg_num, size):
    # return True only if pool number will be OK
    global num_osds
    global pools
    global max_pgs_per_osd
    max_pgs = max_pgs_per_osd * num_osds
    projected = 0
    if pool < 0:
        projected = projected + (pg_num * size)
    for pool_name, pool_sizes in pools.iteritems():
        if pool_name == pool:
            projected = projected + (pg_num * size)
        else:
            projected = projected + (pool_sizes['pg_num'] * pool_sizes['size'])
    if projected > max_pgs:
        print "\nERROR: failed to add pool: " + str(pool)
        print " pg_num " + str(pg_num) + " size " + str(size),
        print "would mean " + str(projected),
        print " total pgs, which exceeds max " + str(max_pgs)
        print " (mon_max_pg_per_osd " + str(max_pgs_per_osd),
        print " * num_in_osds " + str(num_osds) + ")"
        return False
    return True

print "Testing with: %i OSDs %i pools %i for pg_num\n" % (num_osds, len(osp_pools), pg_num)

for pool in osp_pools:
    if check_pg_num(pool, pg_num, size):
        print "Adding " + pool
        pools[pool] = {'pg_num': pg_num, 'size': size}

print "\nFinal pools are:\n"
import pprint
pprint.pprint(pools, width=60) 
