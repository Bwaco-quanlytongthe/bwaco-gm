/* =====================================================
   CHỈ ĐỊNH DATABASE NGUỒN CỦA BWACO
   ===================================================== */
USE EOSVT_STANDBY;
GO

/* =====================================================
   CẤU HÌNH THỜI GIAN
   ===================================================== */
DECLARE @TuThang  INT = 1;
DECLARE @DenThang INT = 5;

DECLARE @Nam_2026 INT = 2026;
DECLARE @Nam_2025 INT = 2025;

/* =====================================================
   CÁC BIẾN LỌC
   ===================================================== */
DECLARE @DS_MAKV NVARCHAR(MAX) = NULL;
DECLARE @MALKHDB VARCHAR(10)   = NULL;
DECLARE @MAMDSD  VARCHAR(10)   = NULL;

DECLARE @DS_MAKH_CHI_LAY NVARCHAR(MAX) = NULL;
DECLARE @DS_MAKH_LOAI     NVARCHAR(MAX) = NULL;

;WITH ds_makv AS (
    SELECT DISTINCT LTRIM(RTRIM(value)) AS makv
    FROM STRING_SPLIT(
        REPLACE(REPLACE(ISNULL(@DS_MAKV,''), CHAR(13), ','), CHAR(10), ','),
        ','
    )
    WHERE LTRIM(RTRIM(value)) <> ''
),

ds_makh_chi_lay AS (
    SELECT DISTINCT LTRIM(RTRIM(value)) AS makh
    FROM STRING_SPLIT(
        REPLACE(REPLACE(ISNULL(@DS_MAKH_CHI_LAY,''), CHAR(13), ','), CHAR(10), ','),
        ','
    )
    WHERE LTRIM(RTRIM(value)) <> ''
),

ds_makh_loai AS (
    SELECT DISTINCT LTRIM(RTRIM(value)) AS makh
    FROM STRING_SPLIT(
        REPLACE(REPLACE(ISNULL(@DS_MAKH_LOAI,''), CHAR(13), ','), CHAR(10), ','),
        ','
    )
    WHERE LTRIM(RTRIM(value)) <> ''
),

/* =====================================================
   DỮ LIỆU 2026
   ===================================================== */
base2026 AS (
    SELECT
        makh      = CONCAT(kh.madp, kh.madb),
        makv      = UPPER(LTRIM(RTRIM(kh.MAKV))),
        kltieuthu = ISNULL(tt.kltieuthu, 0)

    FROM khachhang kh

    JOIN tieuthu tt
        ON tt.IDKH = kh.IDKH
       AND tt.nam = @Nam_2026
       AND tt.thang BETWEEN @TuThang AND @DenThang
       AND (tt.ishuy IS NULL OR tt.ishuy = 0)

    JOIN duongpho dp
        ON dp.madp = kh.madp
       AND dp.duongphu = kh.duongphu

    WHERE
        (@DS_MAKV IS NULL OR kh.MAKV IN (SELECT makv FROM ds_makv))
        AND (@MALKHDB IS NULL OR kh.MALKHDB = @MALKHDB)
        AND (@MAMDSD IS NULL OR tt.mamdsd = @MAMDSD)

        AND (
            @DS_MAKH_CHI_LAY IS NULL
            OR CONCAT(kh.madp, kh.madb)
               IN (SELECT makh FROM ds_makh_chi_lay)
        )

        AND (
            @DS_MAKH_LOAI IS NULL
            OR CONCAT(kh.madp, kh.madb)
               NOT IN (SELECT makh FROM ds_makh_loai)
        )
),

per_makv_2026 AS (
    SELECT
        makv,
        SUM(kltieuthu) AS kltieuthu
    FROM base2026
    GROUP BY makv
),

/* =====================================================
   DỮ LIỆU 2025
   ===================================================== */
base2025 AS (
    SELECT
        makh      = CONCAT(kh.madp, kh.madb),
        makv      = UPPER(LTRIM(RTRIM(kh.MAKV))),
        kltieuthu = ISNULL(tt.kltieuthu, 0)

    FROM khachhang kh

    JOIN tieuthu tt
        ON tt.IDKH = kh.IDKH
       AND tt.nam = @Nam_2025
       AND tt.thang BETWEEN @TuThang AND @DenThang
       AND (tt.ishuy IS NULL OR tt.ishuy = 0)

    JOIN duongpho dp
        ON dp.madp = kh.madp
       AND dp.duongphu = kh.duongphu

    WHERE
        (@DS_MAKV IS NULL OR kh.MAKV IN (SELECT makv FROM ds_makv))
        AND (@MALKHDB IS NULL OR kh.MALKHDB = @MALKHDB)
        AND (@MAMDSD IS NULL OR tt.mamdsd = @MAMDSD)

        AND (
            @DS_MAKH_CHI_LAY IS NULL
            OR CONCAT(kh.madp, kh.madb)
               IN (SELECT makh FROM ds_makh_chi_lay)
        )

        AND (
            @DS_MAKH_LOAI IS NULL
            OR CONCAT(kh.madp, kh.madb)
               NOT IN (SELECT makh FROM ds_makh_loai)
        )
),

per_makv_2025 AS (
    SELECT
        makv,
        SUM(kltieuthu) AS kltieuthu
    FROM base2025
    GROUP BY makv
),

/* =====================================================
   SO SÁNH
   ===================================================== */
data_by_makv AS (
    SELECT
        makv = COALESCE(p26.makv, p25.makv),

        kltieuthu_2025 = ISNULL(p25.kltieuthu, 0),

        kltieuthu_2026 = ISNULL(p26.kltieuthu, 0),

        chenh_khoiluong =
            ISNULL(p26.kltieuthu, 0)
          - ISNULL(p25.kltieuthu, 0)

    FROM per_makv_2026 p26

    FULL JOIN per_makv_2025 p25
        ON p26.makv = p25.makv
),

/* =====================================================
   TỔNG BWACO
   ===================================================== */
tot AS (
    SELECT
        SUM(kltieuthu_2025) AS tot_2025,
        SUM(kltieuthu_2026) AS tot_2026,
        SUM(chenh_khoiluong) AS tot_chenh
    FROM data_by_makv
),

/* =====================================================
   FINAL REPORT
   ===================================================== */
final_report AS (

    /* DÒNG CHI TIẾT */
    SELECT
        1 AS sort_order,

        d.makv AS MAKV_CODE,

        CASE
            WHEN d.makv IN ('VT', 'VNGTAU') THEN N'VŨNG TÀU'
            WHEN d.makv IN ('BR', 'BRIA')   THEN N'BÀ RỊA'
            WHEN d.makv IN ('LD', 'LDIEN')  THEN N'LONG ĐIỀN'
            WHEN d.makv IN ('XM', 'XMOC')   THEN N'XUYÊN MỘC'
            WHEN d.makv IN ('CD', 'CDUC')   THEN N'CHÂU ĐỨC'
            ELSE CONCAT(N'KHU VỰC KHÁC (', d.makv, ')')
        END AS MAKV,

        CAST(d.kltieuthu_2025 AS DECIMAL(18,0)) AS TH2025,

        CAST(d.kltieuthu_2026 AS DECIMAL(18,0)) AS TH2026,

        CAST(d.chenh_khoiluong AS DECIMAL(18,0)) AS CHENH,

        CAST(
            100.0 * d.chenh_khoiluong
            / NULLIF(d.kltieuthu_2025, 0)
            AS DECIMAL(18,2)
        ) AS TANGTRUONG

    FROM data_by_makv d

    UNION ALL

    /* DÒNG TỔNG BWACO */
    SELECT
        2 AS sort_order,

        'BWACO' AS MAKV_CODE,

        N'================ BWACO ================' AS MAKV,

        CAST(t.tot_2025 AS DECIMAL(18,0)) AS TH2025,

        CAST(t.tot_2026 AS DECIMAL(18,0)) AS TH2026,

        CAST(t.tot_chenh AS DECIMAL(18,0)) AS CHENH,

        CAST(
            100.0 * t.tot_chenh
            / NULLIF(t.tot_2025, 0)
            AS DECIMAL(18,2)
        ) AS TANGTRUONG

    FROM tot t
)

/* =====================================================
   OUTPUT
   ===================================================== */
SELECT

    MAKV AS [MAKV],

    RIGHT(
        SPACE(15)
        + FORMAT(TH2025, '#,##0', 'vi-VN'),
        15
    ) AS [THỰC HIỆN LŨY KẾ 5T/2025],

    RIGHT(
        SPACE(15)
        + FORMAT(TH2026, '#,##0', 'vi-VN'),
        15
    ) AS [THỰC HIỆN LŨY KẾ 5T/2026],

    RIGHT(
        SPACE(15)
        + FORMAT(CHENH, '#,##0', 'vi-VN'),
        15
    ) AS [SO SÁNH TĂNG GIẢM (+/-)],

    RIGHT(
        SPACE(10)
        + FORMAT(TANGTRUONG, '#,##0.##', 'vi-VN') + ' %',
        10
    ) AS [% TĂNG TRƯỞNG]

FROM final_report

ORDER BY
    sort_order ASC,

    CASE
        WHEN MAKV_CODE IN ('VT', 'VNGTAU') THEN 1
        WHEN MAKV_CODE IN ('BR', 'BRIA')   THEN 2
        WHEN MAKV_CODE IN ('LD', 'LDIEN')  THEN 3
        WHEN MAKV_CODE IN ('XM', 'XMOC')   THEN 4
        WHEN MAKV_CODE IN ('CD', 'CDUC')   THEN 5
        ELSE 6
    END ASC;
GO