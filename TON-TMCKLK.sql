/* ===================================================
   CẤU HÌNH BIẾN: NHẬP KỲ VÀ NGÀY MUỐN XEM
   =================================================== */
USE EOSVT_Standby
GO

-- 1. Nhập khoảng Kỳ muốn xem (Ví dụ: Từ kỳ 1 đến kỳ 5 năm 2026)
DECLARE @TuThang INT = 1;
DECLARE @TuNam   INT = 2026;

DECLARE @DenThang INT = 5;
DECLARE @DenNam   INT = 2026;

-- 2. Nhập ngày chốt muốn xem
DECLARE @NgayMoc DATE = '2026-06-18'; 

-- 3. Cấu hình mã khu vực
DECLARE @MAKV VARCHAR(50) = 'BR';
--DECLARE @MAKV VARCHAR(50) = NULL;

/* ===================================================
   TỰ ĐỘNG TÍNH TOÁN NGÀY GIỚI HẠN KỲ
   =================================================== */
DECLARE @NgayDauKy_Tu DATE = DATEFROMPARTS(@TuNam, @TuThang, 1);
DECLARE @NgayCuoiKy_Den DATE = EOMONTH(DATEFROMPARTS(@DenNam, @DenThang, 1));

/* ===================================================
   XỬ LÝ DỮ LIỆU VÀ XUẤT BÁO CÁO THEO FORM BẢNG
   =================================================== */
-- Bước 1: Tạo danh mục nhân viên cố định để sắp xếp thứ tự và hiển thị tên Tiếng Việt
WITH ds_manvn AS (
    SELECT 'BAOCQ' AS MANVN_CS, N'BẢO' AS TEN, 1 AS sort_order UNION ALL
    SELECT 'BAYHV',           N'BẢY',        2 UNION ALL
    SELECT 'HANTN',           N'HÀ',         3 UNION ALL
    SELECT 'HIENLTT',         N'HIỀN',        4 UNION ALL
    SELECT 'THAOLN',          N'THẢO',       5 UNION ALL
    SELECT 'YENDT',           N'YẾN',        6 UNION ALL
    SELECT N'TỔNG',           N'TỔNG TỒN',   99
),
-- Bước 2: Lọc dữ liệu tiêu thụ phát sinh trong khoảng Kỳ và thỏa mãn điều kiện ngày mốc
base_tt AS (
    SELECT
        tt.mahttt,
        manvn_cs = UPPER(LTRIM(RTRIM(ISNULL(tt.manvn_cs, ''))))
    FROM tieuthu tt
    INNER JOIN khachhang kh ON kh.idkh = tt.idkh
    WHERE
        -- Lọc trong khoảng từ Kỳ đến Kỳ bằng cách quy đổi ra ngày đầu/cuối tháng
        DATEFROMPARTS(tt.nam, tt.thang, 1) >= @NgayDauKy_Tu
        AND DATEFROMPARTS(tt.nam, tt.thang, 1) <= @NgayCuoiKy_Den
        
        -- Lọc điều kiện Mã khu vực
        AND (
            @MAKV IS NULL
            OR UPPER(kh.makv) IN (
                SELECT UPPER(LTRIM(RTRIM(value)))
                FROM STRING_SPLIT(@MAKV, ',')
                WHERE LTRIM(RTRIM(value)) <> ''
            )
        )
        -- Điều kiện nợ tính đến Ngày Mốc
        AND CAST(tt.ngaynhap_cs AS DATE) <= @NgayMoc
        AND (CAST(tt.ngaynhapcn AS DATE) > @NgayMoc OR ISNULL(tt.hetno, 0) <> 1)
        
        -- Chỉ tính hóa đơn có tiền
        AND IIF(
                tt.INHD_TT = 0,
                ISNULL(tt.TONGTIENPS_1, 0) + ISNULL(tt.TONGTIEN_PS, 0),
                ISNULL(tt.TONGTIEN_PS, 0)
            ) > 0
),
-- Bước 3: Tính toán lũy kế số lượng tồn cho từng nhân viên
calc AS (
    SELECT
        MANVN_CS = manvn_cs,
        TON_CK_LUY_KE = SUM(CASE WHEN UPPER(ISNULL(mahttt, '')) = 'AB' THEN 1 ELSE 0 END),
        TON_TM_LUY_KE = SUM(CASE WHEN ISNULL(UPPER(mahttt), '') <> 'AB' THEN 1 ELSE 0 END),
        TONG_THEO_NV  = COUNT(1)
    FROM base_tt
    WHERE manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT')
    GROUP BY manvn_cs

    UNION ALL

    -- Tính dòng TỔNG TỒN ở cuối bảng
    SELECT
        MANVN_CS = N'TỔNG',
        TON_CK_LUY_KE = SUM(CASE WHEN UPPER(ISNULL(mahttt, '')) = 'AB' AND manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT') THEN 1 ELSE 0 END),
        TON_TM_LUY_KE = SUM(CASE WHEN ISNULL(UPPER(mahttt), '') <> 'AB' AND manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT') THEN 1 ELSE 0 END),
        TONG_THEO_NV  = SUM(CASE WHEN manvn_cs IN ('BAOCQ', 'BAYHV', 'HANTN', 'HIENLTT', 'THAOLN', 'YENDT') THEN 1 ELSE 0 END)
    FROM base_tt
)
-- Bước 4: Hiển thị kết quả map chuẩn theo tên hiển thị của bảng trong ảnh
SELECT
    d.TEN AS [TÊN],
    ISNULL(c.TON_CK_LUY_KE, 0) AS [TỒN CK LŨY KẾ],
    ISNULL(c.TON_TM_LUY_KE, 0) AS [TỒN TM LŨY KẾ],
    ISNULL(c.TONG_THEO_NV,  0) AS [TỔNG THEO NV]
FROM ds_manvn d
LEFT JOIN calc c ON c.MANVN_CS = d.MANVN_CS
ORDER BY d.sort_order;