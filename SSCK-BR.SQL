USE EOSVT_STANDBY;
GO

/* =========================================================
   BÁO CÁO SO SÁNH TĂNG GIẢM
   KHU VỰC BR
   ========================================================= */

DECLARE @MAKV VARCHAR(10) = 'BR';

DECLARE @THANG INT =5;

DECLARE @NAM_2025 INT = 2025;
DECLARE @NAM_2026 INT = 2026;

/* =========================================================
   DỮ LIỆU 2025
   ========================================================= */
;WITH DATA_2025 AS
(
    SELECT

        CASE
            WHEN UPPER(LTRIM(RTRIM(tt.mamdsd))) = 'H'
                THEN N'SINH HOẠT'

            WHEN UPPER(LTRIM(RTRIM(tt.mamdsd))) = 'K'
                THEN N'KINH DOANH'

            WHEN UPPER(LTRIM(RTRIM(tt.mamdsd))) = 'Q'
                THEN N'CƠ QUAN'

            WHEN UPPER(LTRIM(RTRIM(tt.mamdsd))) = 'S'
                THEN N'SẢN XUẤT'

            ELSE N'KHÁC'
        END AS TEN_NHOM,

        UPPER(LTRIM(RTRIM(tt.mamdsd))) AS MA_NHOM,

        SUM(ISNULL(tt.kltieuthu,0)) AS SL_2025

    FROM khachhang kh

    JOIN tieuthu tt
        ON tt.IDKH = kh.IDKH
       AND tt.nam = @NAM_2025
       AND tt.thang = @THANG
       AND (tt.ishuy IS NULL OR tt.ishuy = 0)

    WHERE
        UPPER(LTRIM(RTRIM(kh.MAKV))) = @MAKV

        AND UPPER(LTRIM(RTRIM(tt.mamdsd)))
            IN ('H','K','Q','S')

    GROUP BY
        UPPER(LTRIM(RTRIM(tt.mamdsd)))
),

/* =========================================================
   DỮ LIỆU 2026
   ========================================================= */
DATA_2026 AS
(
    SELECT

        UPPER(LTRIM(RTRIM(tt.mamdsd))) AS MA_NHOM,

        SUM(ISNULL(tt.kltieuthu,0)) AS SL_2026

    FROM khachhang kh

    JOIN tieuthu tt
        ON tt.IDKH = kh.IDKH
       AND tt.nam = @NAM_2026
       AND tt.thang = @THANG
       AND (tt.ishuy IS NULL OR tt.ishuy = 0)

    WHERE
        UPPER(LTRIM(RTRIM(kh.MAKV))) = @MAKV

        AND UPPER(LTRIM(RTRIM(tt.mamdsd)))
            IN ('H','K','Q','S')

    GROUP BY
        UPPER(LTRIM(RTRIM(tt.mamdsd)))
),

/* =========================================================
   GHÉP DỮ LIỆU
   ========================================================= */
REPORT AS
(
    SELECT

        CASE
            WHEN d25.MA_NHOM = 'H' THEN 1
            WHEN d25.MA_NHOM = 'K' THEN 2
            WHEN d25.MA_NHOM = 'Q' THEN 3
            WHEN d25.MA_NHOM = 'S' THEN 4
            ELSE 99
        END AS STT,

        d25.TEN_NHOM,

        d25.MA_NHOM,

        ISNULL(d25.SL_2025,0) AS T5_2025,

        ISNULL(d26.SL_2026,0) AS T5_2026,

        ISNULL(d26.SL_2026,0)
        - ISNULL(d25.SL_2025,0)
        AS TANG_GIAM,

        CASE
            WHEN ISNULL(d25.SL_2025,0) = 0
                THEN 0

            ELSE
                (
                    (
                        ISNULL(d26.SL_2026,0)
                        - ISNULL(d25.SL_2025,0)
                    ) * 100.0
                )
                / ISNULL(d25.SL_2025,0)

        END AS TYLE

    FROM DATA_2025 d25

    LEFT JOIN DATA_2026 d26
        ON d25.MA_NHOM = d26.MA_NHOM
),

/* =========================================================
   TỔNG CỘNG
   ========================================================= */
FINAL_DATA AS
(
    SELECT
        STT,
        TEN_NHOM,
        MA_NHOM,
        T5_2025,
        T5_2026,
        TANG_GIAM,
        TYLE
    FROM REPORT

    UNION ALL

    SELECT
        999,

        N'TỔNG CỘNG',

        '',

        SUM(T5_2025),

        SUM(T5_2026),

        SUM(TANG_GIAM),

        CASE
            WHEN SUM(T5_2025)=0
                THEN 0

            ELSE
                (
                    SUM(TANG_GIAM) * 100.0
                )
                / SUM(T5_2025)

        END

    FROM REPORT
)

/* =========================================================
   OUTPUT
   ========================================================= */
SELECT

    [MÃ NHÓM] =
        MA_NHOM,

    [NHÓM ĐƠN VỊ SỬ DỤNG] =
        TEN_NHOM,

    [T5/2025] =
        FORMAT(T5_2025,'#,##0','vi-VN'),

    [T5/2026] =
        FORMAT(T5_2026,'#,##0','vi-VN'),

    [TĂNG, GIẢM] =
        FORMAT(TANG_GIAM,'#,##0','vi-VN'),

    [%] =
        FORMAT(TYLE,'#,##0.##','vi-VN') + ' %'

FROM FINAL_DATA

ORDER BY STT;
GO

