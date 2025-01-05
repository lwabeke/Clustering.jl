using Test
using Clustering
using Distances
include("test_helpers.jl")

@testset "dbscan() (DBSCAN clustering)" begin

@testset "Argument checks" begin
    Random.seed!(34568)
    @test_throws ArgumentError dbscan(randn(2, 3), 1.0, metric=nothing, min_neighbors=1)
    @test_throws ArgumentError dbscan(randn(1, 1), 1.0, metric=nothing, min_neighbors=1)
    @test_throws ArgumentError dbscan(randn(2, 2), -1.0, metric=nothing, min_neighbors=1)
    @test_throws ArgumentError dbscan(randn(2, 2), 1.0, metric=nothing, min_neighbors=0)
    @test @inferred(dbscan(randn(2, 2), 0.5, metric=nothing, min_neighbors=1)) isa DbscanResult
end

@testset "Simple 2D tests" begin
    X = [10.0  0.0   10.5
          0.0  10.0  0.1]

    @testset "n=3 samples" begin
        X3 = X

        R = dbscan(X3, 20)
        @test nclusters(R) == 1

        R = dbscan(X3, 1.0)
        @test nclusters(R) == 2

        R = dbscan(X3, 0.1)
        @test nclusters(R) == 3
    end

    @testset "n=2 samples" begin
        X2 = X[:, 1:2]

        R = dbscan(X2, 20)
        @test nclusters(R) == 1

        R = dbscan(X2, 1.0)
        @test nclusters(R) == 2
    end

    @testset "n=1 samples" begin
        X1 = X[:, 1:1]

        R = dbscan(X1, 20)
        @test nclusters(R) == 1

        R = dbscan(X1, 1.0)
        @test nclusters(R) == 1
    end

    @testset "n=0 samples" begin
        X0 = X[:, 1:0]

        R = dbscan(X0, 20)
        @test nclusters(R) == 0
    end
end

@testset "clustering synthetic data with 3 clusters" begin
    Random.seed!(34568)

    n = 200
    X = hcat(randn(2, n) .+ [0., 5.],
             randn(2, n) .+ [-5., 0.],
             randn(2, n) .+ [5., 0.])

    # cluster using distrance matrix
    D = pairwise(Euclidean(), X, dims=2)
    R = @inferred(dbscan(D, 1.0, min_neighbors=10, metric=nothing))
    k = nclusters(R)
    # println("k = $k")
    @test k == 3
    @test k == length(R.seeds)
    @test all(<=(k), R.assignments)
    @test length(R.assignments) == size(X, 2)
    @test length(R.counts) == k
    @test [count(==(c), R.assignments) for c in 1:k] == R.counts
    @test all(>=(n*0.9), R.counts)
    # have cores
    @test all(clu -> length(clu.core_indices) > 0, R.clusters)
    # have boundaries
    @test all(clu -> length(clu.boundary_indices) > 0, R.clusters)

    @testset "NNTree-based implementation gives same clustering as distance matrix-based one" begin
        R2 = @inferred(dbscan(X, 1.0, metric=Euclidean(), min_neighbors=10))
        @test R2 isa DbscanResult
        @test nclusters(R2) == nclusters(R)
        @test R2.assignments == R.assignments
    end

    @testset "Support for arrays other than Matrix{T}" begin
        @testset "$(typeof(M))" for M in equivalent_matrices(D)
            R2 = dbscan(M, 1.0, min_neighbors=10, metric=nothing)  # run on complete subarray
            @test nclusters(R2) == nclusters(R)
            @test R2.assignments == R.assignments
        end
    end

    @testset "Deprecated distance matrix API" begin
        R2 = @test_deprecated(dbscan(D, 1.0, 10))
        @test R2.assignments == R.assignments
    end
end

@testset "detecting outliers (#190)" begin
    v = vcat([.828 .134 .821 .630 .784 .674 .436 .089 .777 .526 .200 .908 .929 .835 .553 .647 .672 .234 .536 .617])
    r = @inferred(dbscan(v, 0.075, min_cluster_size=3))
    @test nclusters(r) == 3
    @test findall(==(0), r.assignments) == [7]
    @test r.clusters[1].core_indices == [1, 3, 5, 9, 12, 13, 14]
    @test isempty(r.clusters[1].boundary_indices)
    @test r.clusters[2].core_indices == [2, 8, 11, 18]
    @test isempty(r.clusters[2].boundary_indices)
    @test r.clusters[3].core_indices == [4, 6, 10, 15, 16, 17, 19, 20]
    @test isempty(r.clusters[3].boundary_indices)

    # outlier pt #7 assigned to a 3rd cluster when bigger radius is used
    r2 = @inferred(dbscan(v, 0.1, min_cluster_size=3))
    @test r2.assignments == setindex!(copy(r.assignments), 3, 7)
end

@testset "normal points" begin
    p0 = randn(StableRNG(0), 3, 1000)
    p1 = randn(StableRNG(1), 3, 1000) .+ [3.0, 3.0, 0.0]
    p2 = randn(StableRNG(2), 3, 1000) .+ [-3.0, -3.0, 0.0]

    points = [p0 p1 p2]

    # FIXME Current tests depend too much on a specific random sequence
    #       We need better tests, that check point coordinates rather their indices
    inds_1 = [1, 3, 4, 5, 6, 9, 10, 12, 18, 22, 26, 29, 33, 35, 36, 39, 40, 42, 43, 46, 48, 50, 51, 52, 56, 57, 58, 60, 62, 63, 65, 70, 71, 72, 73, 74, 76, 80, 81, 84, 85, 86, 90, 91, 94, 95, 97, 100, 101, 102, 104, 107, 108, 112, 113, 114, 116, 117, 118, 119, 123, 124, 125, 126, 128, 129, 130, 131, 133, 134, 135, 136, 137, 138, 142, 145, 155, 157, 159, 160, 161, 162, 167, 168, 169, 170, 172, 174, 175, 177, 180, 181, 182, 184, 185, 187, 189, 190, 191, 197, 199, 204, 205, 208, 209, 212, 215, 217, 218, 219, 221, 223, 225, 227, 228, 229, 230, 231, 237, 239, 240, 241, 247, 248, 249, 251, 254, 256, 259, 261, 264, 265, 266, 268, 274, 277, 282, 283, 284, 285, 287, 288, 289, 290, 293, 294, 295, 298, 304, 305, 307, 308, 311, 312, 316, 317, 319, 320, 321, 323, 325, 330, 335, 339, 340, 343, 344, 345, 347, 363, 364, 365, 366, 367, 370, 371, 373, 378, 383, 385, 388, 391, 393, 396, 400, 402, 403, 404, 405, 406, 409, 411, 412, 415, 416, 417, 418, 421, 422, 423, 425, 426, 427, 430, 433, 435, 440, 441, 442, 444, 448, 450, 451, 453, 462, 464, 467, 472, 473, 474, 476, 482, 484, 485, 488, 489, 490, 492, 494, 496, 497, 498, 499, 500, 501, 503, 504, 505, 506, 508, 515, 519, 520, 526, 529, 530, 531, 532, 533, 536, 537, 542, 548, 556, 559, 562, 563, 565, 566, 567, 570, 574, 575, 576, 582, 584, 587, 588, 590, 591, 598, 600, 601, 602, 603, 604, 605, 608, 609, 612, 613, 614, 617, 621, 622, 623, 625, 627, 628, 629, 635, 636, 639, 641, 647, 650, 653, 655, 657, 659, 660, 661, 662, 665, 666, 667, 670, 671, 673, 674, 675, 676, 677, 679, 681, 683, 686, 688, 691, 694, 695, 696, 699, 701, 704, 706, 708, 711, 712, 713, 715, 717, 719, 720, 723, 724, 727, 729, 730, 731, 735, 739, 740, 741, 742, 743, 744, 746, 747, 750, 751, 755, 756, 761, 770, 772, 773, 774, 775, 780, 784, 787, 788, 790, 792, 794, 797, 800, 801, 802, 805, 806, 808, 809, 813, 814, 815, 816, 817, 821, 822, 824, 826, 827, 828, 830, 832, 833, 834, 835, 837, 843, 846, 847, 848, 850, 851, 854, 855, 857, 859, 862, 863, 864, 867, 869, 870, 872, 873, 875, 876, 878, 879, 880, 881, 884, 886, 887, 888, 889, 890, 892, 894, 901, 902, 908, 909, 913, 914, 917, 918, 919, 920, 922, 924, 928, 933, 934, 935, 936, 938, 940, 941, 943, 944, 948, 949, 950, 952, 953, 954, 960, 961, 965, 966, 970, 971, 979, 980, 983, 985, 986, 987, 990, 991, 993, 996, 1000, 1339, 2143]
    inds_2 = [132, 1001, 1003, 1006, 1008, 1011, 1014, 1015, 1017, 1018, 1019, 1020, 1023, 1024, 1027, 1028, 1034, 1036, 1039, 1042, 1044, 1045, 1047, 1049, 1051, 1052, 1056, 1057, 1058, 1059, 1064, 1065, 1068, 1070, 1071, 1076, 1081, 1084, 1087, 1089, 1090, 1093, 1094, 1095, 1096, 1097, 1099, 1100, 1102, 1103, 1108, 1110, 1111, 1112, 1113, 1119, 1120, 1123, 1124, 1125, 1130, 1131, 1136, 1140, 1142, 1143, 1146, 1147, 1156, 1158, 1161, 1162, 1167, 1168, 1172, 1174, 1176, 1177, 1178, 1179, 1183, 1186, 1187, 1190, 1191, 1192, 1193, 1200, 1201, 1202, 1203, 1206, 1209, 1210, 1212, 1213, 1215, 1217, 1219, 1222, 1226, 1229, 1230, 1231, 1232, 1233, 1239, 1241, 1242, 1244, 1246, 1247, 1249, 1250, 1251, 1256, 1257, 1258, 1260, 1261, 1263, 1264, 1265, 1266, 1268, 1275, 1276, 1282, 1285, 1286, 1287, 1291, 1293, 1294, 1295, 1300, 1303, 1307, 1308, 1313, 1315, 1318, 1320, 1325, 1331, 1333, 1336, 1337, 1341, 1345, 1346, 1347, 1348, 1350, 1351, 1355, 1358, 1360, 1361, 1362, 1364, 1365, 1368, 1370, 1372, 1373, 1374, 1378, 1379, 1381, 1382, 1383, 1386, 1392, 1393, 1394, 1396, 1397, 1398, 1400, 1401, 1405, 1406, 1408, 1410, 1413, 1415, 1416, 1418, 1419, 1420, 1421, 1426, 1431, 1433, 1434, 1437, 1441, 1445, 1446, 1447, 1448, 1452, 1453, 1454, 1455, 1459, 1462, 1463, 1464, 1466, 1467, 1468, 1473, 1474, 1476, 1477, 1478, 1480, 1484, 1485, 1487, 1489, 1490, 1492, 1493, 1499, 1501, 1502, 1503, 1504, 1505, 1507, 1514, 1515, 1517, 1519, 1521, 1522, 1524, 1526, 1528, 1529, 1534, 1541, 1542, 1544, 1545, 1546, 1551, 1552, 1553, 1555, 1556, 1561, 1564, 1566, 1567, 1568, 1569, 1571, 1574, 1575, 1576, 1583, 1586, 1588, 1589, 1590, 1592, 1594, 1596, 1597, 1598, 1599, 1601, 1602, 1603, 1604, 1606, 1607, 1608, 1609, 1610, 1612, 1615, 1618, 1619, 1620, 1621, 1622, 1623, 1624, 1627, 1629, 1633, 1635, 1641, 1643, 1646, 1647, 1648, 1649, 1650, 1651, 1652, 1654, 1656, 1658, 1659, 1661, 1662, 1663, 1664, 1665, 1666, 1667, 1668, 1669, 1670, 1673, 1678, 1683, 1684, 1685, 1690, 1692, 1696, 1700, 1701, 1703, 1705, 1706, 1708, 1709, 1710, 1712, 1713, 1716, 1718, 1719, 1720, 1722, 1723, 1725, 1726, 1727, 1729, 1730, 1736, 1737, 1738, 1739, 1740, 1742, 1743, 1744, 1747, 1748, 1749, 1752, 1755, 1758, 1761, 1769, 1771, 1775, 1776, 1777, 1785, 1787, 1791, 1793, 1794, 1795, 1796, 1797, 1798, 1799, 1803, 1805, 1806, 1808, 1811, 1816, 1818, 1821, 1822, 1827, 1828, 1829, 1830, 1831, 1834, 1838, 1839, 1845, 1849, 1850, 1851, 1852, 1853, 1857, 1859, 1864, 1867, 1869, 1870, 1871, 1872, 1878, 1886, 1888, 1889, 1898, 1900, 1901, 1904, 1908, 1912, 1913, 1914, 1915, 1916, 1917, 1919, 1921, 1924, 1929, 1932, 1933, 1935, 1936, 1938, 1940, 1941, 1942, 1948, 1949, 1951, 1952, 1954, 1955, 1957, 1962, 1964, 1965, 1966, 1973, 1976, 1977, 1978, 1979, 1984, 1985, 1988, 1993, 1994, 1996, 1998, 1999]
    inds_3 = [589, 703, 2002, 2004, 2005, 2006, 2008, 2010, 2014, 2015, 2016, 2017, 2019, 2022, 2023, 2024, 2025, 2031, 2032, 2035, 2036, 2038, 2041, 2042, 2044, 2046, 2048, 2052, 2053, 2056, 2057, 2058, 2059, 2060, 2063, 2066, 2070, 2071, 2072, 2073, 2075, 2076, 2078, 2080, 2081, 2083, 2085, 2088, 2089, 2093, 2096, 2097, 2098, 2099, 2101, 2103, 2105, 2106, 2107, 2108, 2109, 2110, 2111, 2112, 2113, 2114, 2115, 2116, 2117, 2120, 2124, 2125, 2126, 2127, 2128, 2129, 2135, 2136, 2138, 2142, 2144, 2146, 2147, 2151, 2152, 2155, 2163, 2164, 2165, 2166, 2172, 2173, 2176, 2177, 2178, 2185, 2186, 2187, 2189, 2190, 2191, 2193, 2195, 2196, 2197, 2198, 2200, 2201, 2203, 2204, 2205, 2211, 2213, 2214, 2215, 2218, 2219, 2221, 2228, 2231, 2233, 2236, 2237, 2238, 2239, 2240, 2241, 2242, 2245, 2249, 2250, 2251, 2252, 2253, 2258, 2259, 2260, 2265, 2270, 2273, 2274, 2275, 2277, 2279, 2280, 2281, 2282, 2283, 2284, 2285, 2286, 2287, 2290, 2291, 2292, 2294, 2296, 2297, 2299, 2301, 2303, 2304, 2305, 2306, 2310, 2311, 2312, 2316, 2317, 2322, 2324, 2325, 2329, 2331, 2332, 2333, 2334, 2335, 2336, 2339, 2341, 2342, 2343, 2344, 2349, 2350, 2351, 2355, 2356, 2359, 2360, 2362, 2364, 2365, 2368, 2370, 2372, 2377, 2380, 2384, 2385, 2386, 2388, 2393, 2403, 2404, 2405, 2406, 2407, 2410, 2411, 2412, 2415, 2418, 2420, 2421, 2422, 2423, 2427, 2428, 2430, 2433, 2434, 2437, 2439, 2440, 2441, 2442, 2443, 2445, 2449, 2452, 2453, 2455, 2458, 2459, 2462, 2464, 2473, 2474, 2479, 2481, 2482, 2484, 2485, 2487, 2488, 2489, 2493, 2494, 2495, 2499, 2504, 2508, 2511, 2513, 2515, 2517, 2521, 2524, 2528, 2530, 2534, 2535, 2536, 2537, 2539, 2540, 2541, 2543, 2545, 2547, 2548, 2549, 2550, 2551, 2555, 2560, 2561, 2562, 2564, 2570, 2572, 2574, 2576, 2578, 2583, 2584, 2585, 2587, 2594, 2595, 2597, 2598, 2599, 2602, 2603, 2605, 2608, 2610, 2611, 2612, 2614, 2618, 2620, 2621, 2623, 2625, 2626, 2627, 2629, 2631, 2632, 2634, 2636, 2637, 2641, 2643, 2647, 2648, 2649, 2652, 2655, 2656, 2657, 2663, 2670, 2672, 2674, 2675, 2676, 2677, 2679, 2680, 2685, 2687, 2691, 2693, 2695, 2696, 2697, 2698, 2700, 2702, 2703, 2706, 2707, 2711, 2713, 2715, 2716, 2717, 2718, 2719, 2721, 2722, 2723, 2724, 2726, 2728, 2730, 2736, 2737, 2739, 2740, 2741, 2745, 2747, 2750, 2752, 2754, 2755, 2758, 2759, 2763, 2764, 2765, 2767, 2770, 2771, 2772, 2774, 2777, 2783, 2784, 2786, 2787, 2790, 2794, 2797, 2800, 2801, 2802, 2803, 2804, 2806, 2807, 2808, 2811, 2817, 2818, 2819, 2822, 2823, 2827, 2830, 2833, 2838, 2839, 2842, 2843, 2844, 2845, 2846, 2850, 2851, 2852, 2857, 2861, 2862, 2863, 2866, 2876, 2877, 2878, 2880, 2881, 2882, 2884, 2885, 2888, 2890, 2891, 2893, 2894, 2895, 2897, 2902, 2904, 2905, 2906, 2909, 2910, 2911, 2915, 2918, 2919, 2922, 2924, 2925, 2926, 2928, 2929, 2930, 2931, 2932, 2933, 2934, 2935, 2936, 2940, 2941, 2942, 2947, 2948, 2950, 2951, 2952, 2960, 2966, 2972, 2973, 2974, 2976, 2977, 2978, 2983, 2985, 2987, 2990, 2991, 2992, 2994, 2996]

    clustering = dbscan(points, 0.3, min_neighbors=3, min_cluster_size=100, leafsize=20)
    @test nclusters(clustering) == 3
    clusters = clustering.clusters
    @test clusters[1].core_indices == inds_1
    @test clusters[2].core_indices == inds_2
    @test clusters[3].core_indices == inds_3

    @testset "Issue #84" begin
        clu1 = dbscan(convert(Matrix{Float32}, points), 0.3f0, min_neighbors=3, min_cluster_size=100, leafsize=20)
        @test nclusters(clu1) == 3
        clu2 = dbscan(convert(Matrix{Float32}, points), 0.3, min_neighbors=3, min_cluster_size=100, leafsize=20)
        @test nclusters(clu2) == nclusters(clu1)
        for i in 1:min(nclusters(clu1), nclusters(clu2))
            c1 = clu1.clusters[i]
            c2 = clu2.clusters[i]
            @test c1.core_indices == c2.core_indices
            @test c1.boundary_indices == c2.boundary_indices
        end
    end
end

end
