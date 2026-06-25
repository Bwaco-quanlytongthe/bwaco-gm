USE EOSVT_STANDBY;
GO

DECLARE @MAKV VARCHAR(10) = 'BR';

------------------------------------------------------------
-- 1. LẤY DỮ LIỆU GỐC VÀ KẾT NỐI DANH MỤC ĐỂ LẤY MALKHDB
------------------------------------------------------------
IF OBJECT_ID('tempdb..#C_KHACH_HANG') IS NOT NULL 
    DROP TABLE #C_KHACH_HANG;

;WITH GHI AS
(
    SELECT
        g.MAKH,
        g.TENKH,
        g.NGAYNHAP,
        ISNULL(g.KLTIEUTHU,0) AS KLTIEUTHU,
        ROW_NUMBER() OVER
        (
            PARTITION BY g.MAKH
            ORDER BY g.NGAYNHAP DESC
        ) AS RN
    FROM dbo.GHICHISOKHACHHANGLON g
    WHERE g.MAKV = @MAKV
      AND YEAR(g.NGAYNHAP) = 2026 
),

SOSANH AS
(
    SELECT
        A.MAKH,
        A.TENKH,
        A.NGAYNHAP AS NGAY_TUAN_NAY,
        B.NGAYNHAP AS NGAY_TUAN_TRUOC,
        ISNULL(A.KLTIEUTHU,0) AS KL_TUAN_NAY,
        ISNULL(B.KLTIEUTHU,0) AS KL_TUAN_TRUOC
    FROM GHI A
    LEFT JOIN GHI B
        ON A.MAKH = B.MAKH
       AND B.RN = 2
    WHERE A.RN = 1
),

-- Đã sửa lỗi chính tả: Đặt tên CTE duy nhất là FILTER_KH
FILTER_KH AS 
(
    SELECT 
        CONCAT(kh.MADP, kh.MADB) AS MAKH_GOC,
        kh.MALKHDB,
        ROW_NUMBER() OVER (PARTITION BY kh.MADP, kh.MADB ORDER BY (SELECT NULL)) AS RN_KH
    FROM dbo.KHACHHANG kh
)
SELECT
    ISNULL(kh.MALKHDB, '1') AS MALKHDB, 
    s.MAKH,
    s.TENKH,
    s.NGAY_TUAN_TRUOC,
    s.NGAY_TUAN_NAY,
    s.KL_TUAN_TRUOC,
    s.KL_TUAN_NAY,
    (s.KL_TUAN_NAY - s.KL_TUAN_TRUOC) AS TANG_GIAM
INTO #C_KHACH_HANG
FROM SOSANH s
LEFT JOIN FILTER_KH kh ON s.MAKH = kh.MAKH_GOC AND kh.RN_KH = 1;


------------------------------------------------------------
-- BẢNG 1: TỔNG HỢP THEO MẪU BẢNG PHÂN LOẠI CHI TIẾT
------------------------------------------------------------
;WITH DANHMUC AS 
(
    SELECT 1 AS STT, N'SINH HOẠT' AS MUC_DICH, N'SINH HOẠT ĐÔ THỊ & NÔNG THÔ' AS NHOM_DON_VI, '1' AS MALKHDB UNION ALL
    SELECT 2, N'CƠ QUAN', N'CƠ QUAN CHÍNH QUYỀN', 'CQ' UNION ALL
    SELECT 3, N'CƠ QUAN', N'LỰC LƯỢNG VŨ TRANG (CÔNG AN, QUÂN ĐỘI)', 'VT' UNION ALL
    SELECT 4, N'CƠ QUAN', N'Y TẾ (CƠ SỞ KHÁM CHỮA BỆNH)', 'YT' UNION ALL
    SELECT 5, N'CƠ QUAN', N'TRƯỜNG HỌC (CƠ SỞ GIÁO DỤC)', 'GD' UNION ALL
    SELECT 6, N'SẢN XUẤT', N'NHÓM CÁC CÔNG TY KHÍ', 'P' UNION ALL
    SELECT 7, N'SẢN XUẤT', N'NHÓM XÂY DỰNG', 'XD' UNION ALL
    SELECT 8, N'SẢN XUẤT', N'NHÓM CHẾ BIẾN HẢI SẢN', 'H' UNION ALL
    SELECT 9, N'KINH DOANH', N'KINH DOANH NHÀ HÀNG - ĂN UỐNG', 'U' UNION ALL
    SELECT 10, N'KINH DOANH', N'PHỤC VỤ DU LỊCH', 'L'
),
DATA_GOM_NHOM AS
(
    SELECT 
        MALKHDB,
        SUM(KL_TUAN_TRUOC) AS TUAN_TRUOC,
        SUM(KL_TUAN_NAY) AS TUAN_NAY,
        SUM(TANG_GIAM) AS TANG_GIAM
    FROM #C_KHACH_HANG
    GROUP BY MALKHDB
),
KETQUA_TUNG_DONG AS
(
    SELECT 
        dm.STT,
        dm.MUC_DICH AS [MỤC ĐÍCH SỬ DỤNG],
        dm.NHOM_DON_VI AS [NHÓM ĐƠN VỊ SỬ DỤNG],
        dm.MALKHDB,
        ISNULL(da.TUAN_TRUOC, 0) AS [TUAN_TRUOC_NUM],
        ISNULL(da.TUAN_NAY, 0) AS [TUAN_NAY_NUM],
        ISNULL(da.TANG_GIAM, 0) AS [TANG_GIAM_NUM],
        CAST(CASE 
            WHEN ISNULL(da.TUAN_TRUOC, 0) = 0 THEN 0 
            ELSE (ISNULL(da.TUAN_NAY, 0) - ISNULL(da.TUAN_TRUOC, 0)) * 100.0 / da.TUAN_TRUOC 
        END AS DECIMAL(18,2)) AS [ % ]
    FROM DANHMUC dm
    LEFT JOIN DATA_GOM_NHOM da ON dm.MALKHDB = da.MALKHDB
),
HIEN_THI_BANG_1 AS
(
    SELECT 
        STT, 
        [MỤC ĐÍCH SỬ DỤNG], 
        [NHÓM ĐƠN VỊ SỬ DỤNG], 
        MALKHDB, 
        REPLACE(CONVERT(VARCHAR, CAST([TUAN_TRUOC_NUM] AS MONEY), 1), '.00', '') AS [TUẦN TRƯỚC], 
        REPLACE(CONVERT(VARCHAR, CAST([TUAN_NAY_NUM] AS MONEY), 1), '.00', '') AS [TUẦN NÀY], 
        REPLACE(CONVERT(VARCHAR, CAST([TANG_GIAM_NUM] AS MONEY), 1), '.00', '') AS [TĂNG, GIẢM], 
        [ % ]
    FROM KETQUA_TUNG_DONG

    UNION ALL

    SELECT 
        999 AS STT,
        N'TỔNG CỘNG SO SÁNH TĂNG GIẢM' AS [MỤC ĐÍCH SỬ DỤNG],
        NULL AS [NHÓM ĐƠN VỊ SỬ DỤNG],
        NULL AS MALKHDB,
        REPLACE(CONVERT(VARCHAR, CAST(SUM(KL_TUAN_TRUOC) AS MONEY), 1), '.00', '') AS [TUẦN TRƯỚC],
        REPLACE(CONVERT(VARCHAR, CAST(SUM(KL_TUAN_NAY) AS MONEY), 1), '.00', '') AS [TUẦN NÀY],
        REPLACE(CONVERT(VARCHAR, CAST(SUM(TANG_GIAM) AS MONEY), 1), '.00', '') AS [TĂNG, GIẢM],
        CAST(CASE 
            WHEN SUM(KL_TUAN_TRUOC) = 0 THEN 0 
            ELSE SUM(TANG_GIAM) * 100.0 / SUM(KL_TUAN_TRUOC) 
        END AS DECIMAL(18,2)) AS [ % ]
    FROM #C_KHACH_HANG
)
SELECT [MỤC ĐÍCH SỬ DỤNG], [NHÓM ĐƠN VỊ SỬ DỤNG], MALKHDB, [TUẦN TRƯỚC], [TUẦN NÀY], [TĂNG, GIẢM], [ % ]
FROM HIEN_THI_BANG_1
ORDER BY STT;


------------------------------------------------------------
-- BẢNG 2: DANH SÁCH CHI TIẾT KHÁCH HÀNG (SẮP XẾP THEO MÃ KH)
------------------------------------------------------------
SELECT
    MAKH AS [MÃ KH],
    TENKH AS [TÊN KHÁCH HÀNG],
    CONVERT(VARCHAR(10), NGAY_TUAN_TRUOC, 103) AS [NGÀY TUẦN TRƯỚC],
    CONVERT(VARCHAR(10), NGAY_TUAN_NAY, 103) AS [NGÀY TUẦN NÀY],
    REPLACE(CONVERT(VARCHAR, CAST(KL_TUAN_TRUOC AS MONEY), 1), '.00', '') AS [KL TUẦN TRƯỚC],
    REPLACE(CONVERT(VARCHAR, CAST(KL_TUAN_NAY AS MONEY), 1), '.00', '') AS [KL TUẦN NÀY],
    REPLACE(CONVERT(VARCHAR, CAST(TANG_GIAM AS MONEY), 1), '.00', '') AS [TĂNG GIẢM],
    CAST(CASE WHEN KL_TUAN_TRUOC = 0 THEN 0 ELSE TANG_GIAM * 100.0 / KL_TUAN_TRUOC END AS DECIMAL(18,2)) AS [TỶ LỆ %]
FROM #C_KHACH_HANG
ORDER BY 
    MAKH;

-- Dọn dẹp bảng tạm
IF OBJECT_ID('tempdb..#C_KHACH_HANG') IS NOT NULL 
    DROP TABLE #C_KHACH_HANG;
GO