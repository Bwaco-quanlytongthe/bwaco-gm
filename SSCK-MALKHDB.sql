USE EOSVT_STANDBY;
GO

/* =====================================================
   CẤU HÌNH CHUẨN
   ===================================================== */

DECLARE @TuThang  INT = 5;
DECLARE @DenThang INT = 5;

DECLARE @Nam_2026 INT = 2026;
DECLARE @Nam_2025 INT = 2025;

DECLARE @MAKV VARCHAR(10) = 'br';
DECLARE @MALKHDB VARCHAR(10) = NULL;
DECLARE @MAMDSD VARCHAR(10) = NULL;

DECLARE @DS_MAKH_CHI_LAY NVARCHAR(MAX) = NULL;

DECLARE @DS_MAKH_LOAI NVARCHAR(MAX) = N'
5499024
';

WITH ds_makh_chi_lay AS (
    SELECT DISTINCT MAKH = LTRIM(RTRIM(value))
    FROM STRING_SPLIT(REPLACE(REPLACE(ISNULL(@DS_MAKH_CHI_LAY,''), CHAR(13), ','), CHAR(10), ','), ',')
    WHERE LTRIM(RTRIM(value)) <> ''
),
ds_makh_loai AS (
    SELECT DISTINCT MAKH = LTRIM(RTRIM(value))
    FROM STRING_SPLIT(REPLACE(REPLACE(ISNULL(@DS_MAKH_LOAI,''), CHAR(13), ','), CHAR(10), ','), ',')
    WHERE LTRIM(RTRIM(value)) <> ''
),

base2026 AS (
    SELECT
        makh = CONCAT(kh.madp, kh.madb),
        kh.MALKHDB,
        kltieuthu = ISNULL(tt.kltieuthu,0)
    FROM khachhang kh
    JOIN tieuthu tt
         ON tt.IDKH = kh.IDKH
        AND tt.nam = @Nam_2026
        AND tt.thang BETWEEN @TuThang AND @DenThang
    JOIN duongpho dp
         ON dp.madp = kh.madp
        AND dp.duongphu = kh.duongphu
    WHERE
        (@MAKV IS NULL OR kh.MAKV = @MAKV)
        AND (@MALKHDB IS NULL OR kh.MALKHDB = @MALKHDB)
        AND (@MAMDSD IS NULL OR tt.mamdsd = @MAMDSD)
        AND (
            @DS_MAKH_CHI_LAY IS NULL
            OR LTRIM(RTRIM(CONCAT(kh.madp, kh.madb))) IN (SELECT MAKH FROM ds_makh_chi_lay)
        )
        AND (
            @DS_MAKH_LOAI IS NULL
            OR LTRIM(RTRIM(CONCAT(kh.madp, kh.madb))) NOT IN (SELECT MAKH FROM ds_makh_loai)
        )
),

per_makh_2026 AS (
    SELECT
        makh,
        MALKHDB = MAX(MALKHDB),
        kltieuthu = SUM(kltieuthu)
    FROM base2026
    GROUP BY makh
),

base2025 AS (
    SELECT
        makh = CONCAT(kh.madp, kh.madb),
        kh.MALKHDB,
        kltieuthu = ISNULL(tt.kltieuthu,0)
    FROM khachhang kh
    JOIN tieuthu tt
         ON tt.IDKH = kh.IDKH
        AND tt.nam = @Nam_2025
        AND tt.thang BETWEEN @TuThang AND @DenThang
    JOIN duongpho dp
         ON dp.madp = kh.madp
        AND dp.duongphu = kh.duongphu
    WHERE
        (@MAKV IS NULL OR kh.MAKV = @MAKV)
        AND (@MALKHDB IS NULL OR kh.MALKHDB = @MALKHDB)
        AND (@MAMDSD IS NULL OR tt.mamdsd = @MAMDSD)
        AND (
            @DS_MAKH_CHI_LAY IS NULL
            OR LTRIM(RTRIM(CONCAT(kh.madp, kh.madb))) IN (SELECT MAKH FROM ds_makh_chi_lay)
        )
        AND (
            @DS_MAKH_LOAI IS NULL
            OR LTRIM(RTRIM(CONCAT(kh.madp, kh.madb))) NOT IN (SELECT MAKH FROM ds_makh_loai)
        )
),

per_makh_2025 AS (
    SELECT
        makh,
        MALKHDB = MAX(MALKHDB),
        kltieuthu = SUM(kltieuthu)
    FROM base2025
    GROUP BY makh
),

data_final AS (
    SELECT
        MALKHDB = ISNULL(COALESCE(p26.MALKHDB, p25.MALKHDB), N'CHƯA PHÂN LOẠI'),
        kltieuthu_2025 = ISNULL(p25.kltieuthu, 0),
        kltieuthu_2026 = ISNULL(p26.kltieuthu, 0),
        chenh_lech = ISNULL(p26.kltieuthu, 0) - ISNULL(p25.kltieuthu, 0)
    FROM per_makh_2026 p26
    FULL JOIN per_makh_2025 p25 ON p26.makh = p25.makh
),

tot_by_loai AS (
    SELECT
        MALKHDB,
        CASE MALKHDB
            WHEN '1'   THEN N'Bình thường'
            WHEN 'CC'  THEN N'chung cư'
            WHEN 'CHU' THEN N'Chung cư cũ/Chưa phân loại'
            WHEN 'CQ'  THEN N'Cơ quan chính quyền'
            WHEN 'D'   THEN N'Sản xuất nước đá'
            WHEN 'DNG' THEN N'Đỗ nước ghe'
            WHEN 'G'   THEN N'Khách hàng làm giá đỗ'
            WHEN 'GD'  THEN N'Cơ sở giáo dục'
            WHEN 'H'   THEN N'Chế biến hải sản'
            WHEN 'K'   THEN N'Nước tinh khiết & KT phụ gia đình'
            WHEN 'L'   THEN N'Phục vụ du lịch'
            WHEN 'NCT' THEN N'Nhà cho thuê'
            WHEN 'NT'  THEN N'Nước nông thôn'
            WHEN 'P'   THEN N'Dầu khí'
            WHEN 'Q'   THEN N'Loại khác'
            WHEN 'TG'  THEN N'Cơ sở tôn giáo'
            WHEN 'TOM' THEN N'Nuôi hải sản'
            WHEN 'TR'  THEN N'Trồng rau'
            WHEN 'U'   THEN N'Kinh doanh ăn uống'
            WHEN 'VIP' THEN N'Khách hàng đặc biệt'
            WHEN 'VT'  THEN N'Lực lực vũ trang'
            WHEN 'YT'  THEN N'Y tế'
            WHEN 'XD'  THEN N'Nhóm xây dựng'
            ELSE N'Mô tả khác'
        END AS TEN_LOAI,
        SUM(kltieuthu_2025) AS T5_2025,
        SUM(kltieuthu_2026) AS T5_2026,
        SUM(chenh_lech) AS TANG_GIAM,
        CAST(100.0 * SUM(chenh_lech) / NULLIF(SUM(kltieuthu_2025), 0) AS DECIMAL(18,2)) AS PHAN_TRAM
    FROM data_final
    GROUP BY MALKHDB
),

tot_all AS (
    SELECT
        SUM(kltieuthu_2025) AS T5_2025,
        SUM(kltieuthu_2026) AS T5_2026,
        SUM(chenh_lech) AS TANG_GIAM,
        CAST(100.0 * SUM(chenh_lech) / NULLIF(SUM(kltieuthu_2025), 0) AS DECIMAL(18,2)) AS PHAN_TRAM
    FROM data_final
),

final_summary AS (
    /* ---- 1. CHI TIẾT CÁC NHÓM SẢN LƯỢNG ---- */
    SELECT
        1 AS part_group,
        CAST(MALKHDB AS NVARCHAR(50)) AS MALKHDB,
        TEN_LOAI AS TEN_NHOM_OR_MAKH, 
        CAST(ROUND(T5_2025, 0) AS INT) AS T5_2025,
        CAST(ROUND(T5_2026, 0) AS INT) AS T5_2026,
        CAST(ROUND(TANG_GIAM, 0) AS INT) AS TANG_GIAM,
        PHAN_TRAM
    FROM tot_by_loai

    UNION ALL

    /* ---- 2. DÒNG TỔNG CỘNG HÀNG CUỐI ---- */
    SELECT
        2 AS part_group,
        NULL AS MALKHDB,
        N'TỔNG CỘNG' AS TEN_NHOM_OR_MAKH,
        CAST(ROUND(T5_2025, 0) AS INT),
        CAST(ROUND(T5_2026, 0) AS INT),
        CAST(ROUND(TANG_GIAM, 0) AS INT),
        PHAN_TRAM
    FROM tot_all
)

/* ---- THỰC THI HIỂN THỊ KẾT QUẢ TINH GỌN ---- */
SELECT 
    MALKHDB, 
    TEN_NHOM_OR_MAKH, 
    REPLACE(FORMAT(T5_2025, '##,#', 'en-US'), ',', '.') AS T5_2025,
    REPLACE(FORMAT(T5_2026, '##,#', 'en-US'), ',', '.') AS T5_2026,
    REPLACE(FORMAT(TANG_GIAM, '##,#', 'en-US'), ',', '.') AS TANG_GIAM,
    CAST(PHAN_TRAM AS DECIMAL(18,2)) AS PHAN_TRAM
FROM final_summary
ORDER BY
    part_group,  
    MALKHDB;

GO