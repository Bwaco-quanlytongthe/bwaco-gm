/* ================================
   CẤU HÌNH BIẾN NGÀY CẦN XEM (CHỈ NHẬP KỲ NÀY)
   ================================ */
USE EOSVT_Standby
GO

DECLARE @Nam2 INT = 2026;
DECLARE @Thang2 INT = 5;
DECLARE @NgayMoc2 DATE = '2026-06-18'; -- Nhập ngày chốt Kỳ 5 tại đây

DECLARE @MAKV VARCHAR(50) = 'BR';
--DECLARE @MAKV VARCHAR(50) = NULL;

/* ===================================================
   TỰ ĐỘNG TÍNH TOÁN THÔNG TIN KỲ TRƯỚC (KHÔNG CẦN SỬA)
   =================================================== */
DECLARE @NgayDauKy2 DATE = DATEFROMPARTS(@Nam2, @Thang2, 1);
DECLARE @NgayMocKyTruoc DATE = DATEADD(MONTH, -1, @NgayDauKy2);

DECLARE @Nam1 INT = YEAR(@NgayMocKyTruoc);
DECLARE @Thang1 INT = MONTH(@NgayMocKyTruoc);
DECLARE @NgayMoc1 DATE = DATEADD(MONTH, -1, @NgayMoc2);

-- Xóa bảng tạm nếu đã tồn tại trước đó
IF OBJECT_ID('tempdb..#BaoCaoTon') IS NOT NULL DROP TABLE #BaoCaoTon;

/* ===================================================
   1. ĐỔ DỮ LIỆU CHUẨN VÀO BẢNG TẠM (SQL THUẦN KHÔNG CHUỖI ĐỘNG)
   =================================================== */
;WITH ds_manvn AS (
    SELECT 'BAOCQ' AS MANVN_CS, 1 AS sort_order UNION ALL
    SELECT 'BAYHV', 2 UNION ALL
    SELECT 'HANTN', 3 UNION ALL
    SELECT 'HIENLTT', 4 UNION ALL
    SELECT 'THAOLN', 5 UNION ALL
    SELECT 'YENDT', 6 UNION ALL
    SELECT N'TỔNG', 99
),
base_tt AS (
    SELECT
        tt.nam,
        tt.thang,
        tt.ngaynhap_cs,
        tt.ngaynhapcn,
        tt.hetno,
        tt.mahttt,
        manvn_cs = UPPER(LTRIM(RTRIM(ISNULL(tt.manvn_cs, '')))),
        kh.makv
    FROM tieuthu tt
    INNER JOIN khachhang kh ON kh.idkh = tt.idkh
    WHERE
        (
            (tt.nam = @Nam1 AND tt.thang = @Thang1)
            OR
            (tt.nam = @Nam2 AND tt.thang = @Thang2)
        )
        AND (
            @MAKV IS NULL
            OR UPPER(kh.makv) IN (
                SELECT UPPER(LTRIM(RTRIM(value)))
                FROM STRING_SPLIT(@MAKV, ',')
                WHERE LTRIM(RTRIM(value)) <> ''
            )
        )
        AND IIF(
                tt.INHD_TT = 0,
                ISNULL(tt.TONGTIENPS_1, 0) + ISNULL(tt.TONGTIEN_PS, 0),
                ISNULL(tt.TONGTIEN_PS, 0)
            ) > 0
),
data_loc AS (
    SELECT *, ky = 2
    FROM base_tt
    WHERE nam = @Nam2 AND thang = @Thang2
      AND CAST(ngaynhap_cs AS DATE) <= @NgayMoc2
      AND (CAST(ngaynhapcn AS DATE) > @NgayMoc2 OR ISNULL(hetno, 0) <> 1)

    UNION ALL

    SELECT *, ky = 1
    FROM base_tt
    WHERE nam = @Nam1 AND thang = @Thang1
      AND CAST(ngaynhap_cs AS DATE) <= @NgayMoc1
      AND (CAST(ngaynhapcn AS DATE) > @NgayMoc1 OR ISNULL(hetno, 0) <> 1)
),
calc AS (
    SELECT
        MANVN_CS = manvn_cs,
        Ky2_CK = SUM(CASE WHEN ky = 2 AND UPPER(ISNULL(mahttt, '')) = 'AB' THEN 1 ELSE 0 END),
        Ky2_TM = SUM(CASE WHEN ky = 2 AND ISNULL(UPPER(mahttt), '') <> 'AB' THEN 1 ELSE 0 END),
        Ky2_TONG = SUM(CASE WHEN ky = 2 THEN 1 ELSE 0 END),
        Ky1_CK = SUM(CASE WHEN ky = 1 AND UPPER(ISNULL(mahttt, '')) = 'AB' THEN 1 ELSE 0 END),
        Ky1_TM = SUM(CASE WHEN ky = 1 AND ISNULL(UPPER(mahttt), '') <> 'AB' THEN 1 ELSE 0 END),
        Ky1_TONG = SUM(CASE WHEN ky = 1 THEN 1 ELSE 0 END)
    FROM data_loc
    WHERE manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT')
    GROUP BY manvn_cs

    UNION ALL

    SELECT
        MANVN_CS = N'TỔNG',
        Ky2_CK = SUM(CASE WHEN ky = 2 AND UPPER(ISNULL(mahttt, '')) = 'AB' AND manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT') THEN 1 ELSE 0 END),
        Ky2_TM = SUM(CASE WHEN ky = 2 AND ISNULL(UPPER(mahttt), '') <> 'AB' AND manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT') THEN 1 ELSE 0 END),
        Ky2_TONG = SUM(CASE WHEN ky = 2 AND manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT') THEN 1 ELSE 0 END),
        Ky1_CK = SUM(CASE WHEN ky = 1 AND UPPER(ISNULL(mahttt, '')) = 'AB' AND manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT') THEN 1 ELSE 0 END),
        Ky1_TM = SUM(CASE WHEN ky = 1 AND ISNULL(UPPER(mahttt), '') <> 'AB' AND manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT') THEN 1 ELSE 0 END),
        Ky1_TONG = SUM(CASE WHEN ky = 1 AND manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT') THEN 1 ELSE 0 END)
    FROM data_loc
)
SELECT
    d.MANVN_CS,
    Ky2_CK   = ISNULL(c.Ky2_CK, 0),
    Ky2_TM   = ISNULL(c.Ky2_TM, 0),
    Ky2_TONG = ISNULL(c.Ky2_TONG, 0),
    Ky1_CK   = ISNULL(c.Ky1_CK, 0),
    Ky1_TM   = ISNULL(c.Ky1_TM, 0),
    Ky1_TONG = ISNULL(c.Ky1_TONG, 0),
    ChenhLech = (ISNULL(c.Ky2_TONG, 0) - ISNULL(c.Ky1_TONG, 0))
INTO #BaoCaoTon
FROM ds_manvn d
LEFT JOIN calc c ON c.MANVN_CS = d.MANVN_CS
ORDER BY d.sort_order;

/* ===================================================
   2. ĐỔI TÊN CỘT ĐỘNG THEO NGÀY MỐC (SIÊU NGẮN & AN TOÀN)
   =================================================== */
DECLARE @CotKy2_CK   NVARCHAR(100) = QUOTENAME(FORMAT(@NgayMoc2, 'dd/MM') + N'_Tồn CK');
DECLARE @CotKy2_TM   NVARCHAR(100) = QUOTENAME(FORMAT(@NgayMoc2, 'dd/MM') + N'_Tồn TM');
DECLARE @CotKy2_TONG NVARCHAR(100) = QUOTENAME(FORMAT(@NgayMoc2, 'dd/MM') + N'_Tồn TM+CK');

DECLARE @CotKy1_CK   NVARCHAR(100) = QUOTENAME(FORMAT(@NgayMoc1, 'dd/MM') + N'_Tồn CK');
DECLARE @CotKy1_TM   NVARCHAR(100) = QUOTENAME(FORMAT(@NgayMoc1, 'dd/MM') + N'_Tồn TM');
DECLARE @CotKy1_TONG NVARCHAR(100) = QUOTENAME(FORMAT(@NgayMoc1, 'dd/MM') + N'_Tồn TM+CK');

DECLARE @ExecSql NVARCHAR(MAX);
SET @ExecSql = N'
SELECT 
    MANVN_CS,
    Ky2_CK   AS ' + @CotKy2_CK + N',
    Ky2_TM   AS ' + @CotKy2_TM + N',
    Ky2_TONG AS ' + @CotKy2_TONG + N',
    Ky1_CK   AS ' + @CotKy1_CK + N',
    Ky1_TM   AS ' + @CotKy1_TM + N',
    Ky1_TONG AS ' + @CotKy1_TONG + N',
    ChenhLech AS [Chênh lệch tổng tồn]
FROM #BaoCaoTon;
';

EXEC sp_executesql @ExecSql;

-- Dọn dẹp bảng tạm sau khi chạy xong
IF OBJECT_ID('tempdb..#BaoCaoTon') IS NOT NULL DROP TABLE #BaoCaoTon;