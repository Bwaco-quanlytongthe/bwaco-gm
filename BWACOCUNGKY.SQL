/* ============================================================================
   BWACO - BÁO CÁO ĐỘNG SO SÁNH NƯỚC THƯƠNG PHẨM CÙNG KỲ TRÊN SSMS
   (Tích hợp Top 10 khách hàng lớn nhất theo từng khu vực ở phía dưới)
   ============================================================================ 
   🛠️ MENU BỘ LỌC TỔNG THỂ (Chỉ cần sửa thông số ở đây và nhấn F5)
   ============================================================================ */
   USE EOSVT_Standby
   GO
DECLARE @Thang_Chon      INT = 5;       -- Chọn tháng muốn xem (1 đến 12)
DECLARE @Nam_Ky_Goc      INT = 2025;    -- Năm gốc đối chiếu
DECLARE @Nam_So_Sanh     INT = 2026;    -- Năm muốn so sánh

-- 💡 Bộ lọc nâng cao (Để NULL nếu muốn lấy toàn bộ hệ thống)
DECLARE @DS_MAKV         NVARCHAR(MAX) = NULL; -- Ví dụ: 'VT,BR,LD' hoặc NULL
DECLARE @MALKHDB         VARCHAR(10)   = NULL; -- Mã loại khách hàng đặc biệt
DECLARE @MAMDSD          VARCHAR(10)   = NULL; -- Mã mục đích sử dụng

-- 💡 Bộ lọc danh sách khách hàng (Phục vụ chạy chuyên sâu)
DECLARE @DS_MAKH_CHI_LAY NVARCHAR(MAX) = NULL; -- Chỉ lấy DS khách hàng này ('madp+madb')
DECLARE @DS_MAKH_LOAI    NVARCHAR(MAX) = NULL; -- Loại trừ DS khách hàng này

/* ============================================================================
   HỆ THỐNG TỰ ĐỘNG XỬ LÝ (KHÔNG CẦN SỬA PHẦN CODE PHÍA DƯỚI)
   ============================================================================ */
SET NOCOUNT ON;

-- 1. Khởi tạo và làm sạch bảng tạm
IF OBJECT_ID('tempdb..#raw_data') IS NOT NULL DROP TABLE #raw_data;
IF OBJECT_ID('tempdb..#tbl_ds_makv') IS NOT NULL DROP TABLE #tbl_ds_makv;
IF OBJECT_ID('tempdb..#tbl_ds_makh_chi_lay') IS NOT NULL DROP TABLE #tbl_ds_makh_chi_lay;
IF OBJECT_ID('tempdb..#tbl_ds_makh_loai') IS NOT NULL DROP TABLE #tbl_ds_makh_loai;
IF OBJECT_ID('tempdb..#customer_data') IS NOT NULL DROP TABLE #customer_data;

CREATE TABLE #tbl_ds_makv (makv NVARCHAR(50));
CREATE TABLE #tbl_ds_makh_chi_lay (makh NVARCHAR(50));
CREATE TABLE #tbl_ds_makh_loai (makh NVARCHAR(50));

-- 2. Tách chuỗi danh sách bộ lọc từ Menu
INSERT INTO #tbl_ds_makv
SELECT DISTINCT LTRIM(RTRIM(value)) FROM STRING_SPLIT(REPLACE(REPLACE(ISNULL(@DS_MAKV,''), CHAR(13), ','), CHAR(10), ','), ',') WHERE LTRIM(RTRIM(value)) <> '';

INSERT INTO #tbl_ds_makh_chi_lay
SELECT DISTINCT LTRIM(RTRIM(value)) FROM STRING_SPLIT(REPLACE(REPLACE(ISNULL(@DS_MAKH_CHI_LAY,''), CHAR(13), ','), CHAR(10), ','), ',') WHERE LTRIM(RTRIM(value)) <> '';

INSERT INTO #tbl_ds_makh_loai
SELECT DISTINCT LTRIM(RTRIM(value)) FROM STRING_SPLIT(REPLACE(REPLACE(ISNULL(@DS_MAKH_LOAI,''), CHAR(13), ','), CHAR(10), ','), ',') WHERE LTRIM(RTRIM(value)) <> '';

/* --- 3. ĐỔ DỮ LIỆU THÔ VÀ CHUẨN HÓA KHU VỰC NGAY TỪ ĐẦU --- */
-- 3.1 Bảng tạm chứa thông tin chi tiết phục vụ cả 2 báo cáo
SELECT 
    CASE 
        WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('VT', 'VNGTAU') THEN N'Vũng Tàu'
        WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('BR', 'BRIA')   THEN N'Bà Rịa'
        WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('LD', 'LDIEN')  THEN N'Long Điền'
        WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('XM', 'XMOC')   THEN N'Xuyên Mộc'
        WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('CD', 'CDUC')   THEN N'Châu Đức'
        ELSE N'Khu vực khác'
    END AS Ten_Khu_Vuc,
    CASE 
        WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('VT', 'VNGTAU') THEN 1
        WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('BR', 'BRIA')   THEN 2
        WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('LD', 'LDIEN')  THEN 3
        WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('XM', 'XMOC')   THEN 4
        WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('CD', 'CDUC')   THEN 5
        ELSE 6
    END AS Khu_Vuc_Order,
    CONCAT(kh.madp, kh.madb) AS Ma_Khach_Hang,
    kh.TENKH AS Ten_Khach_Hang,
    tt.nam,
    SUM(ISNULL(tt.kltieuthu, 0)) AS kltieuthu
INTO #customer_data
FROM EOSVT_STANDBY.dbo.tieuthu tt
LEFT JOIN EOSVT_STANDBY.dbo.khachhang kh ON tt.IDKH = kh.IDKH
LEFT JOIN EOSVT_STANDBY.dbo.duongpho dp  ON dp.madp = kh.madp AND dp.duongphu = kh.duongphu
WHERE
    tt.thang = @Thang_Chon
    AND tt.nam IN (@Nam_Ky_Goc, @Nam_So_Sanh)
    AND (tt.ishuy IS NULL OR tt.ishuy = 0)
    -- Áp dụng Menu bộ lọc động
    AND (@DS_MAKV IS NULL OR kh.MAKV IN (SELECT makv FROM #tbl_ds_makv))
    AND (@MALKHDB IS NULL OR kh.MALKHDB = @MALKHDB)
    AND (@MAMDSD IS NULL OR tt.mamdsd = @MAMDSD)
    AND (@DS_MAKH_CHI_LAY IS NULL OR CONCAT(kh.madp, kh.madb) IN (SELECT makh FROM #tbl_ds_makh_chi_lay))
    AND (@DS_MAKH_LOAI IS NULL OR CONCAT(kh.madp, kh.madb) NOT IN (SELECT makh FROM #tbl_ds_makh_loai))
GROUP BY 
    kh.MAKV, CONCAT(kh.madp, kh.madb), kh.TENKH, tt.nam;

-- 3.2 Gom nhóm theo khu vực (Kế thừa từ code cũ)
SELECT 
    Ten_Khu_Vuc,
    Khu_Vuc_Order,
    nam,
    SUM(kltieuthu) AS kltieuthu
INTO #raw_data
FROM #customer_data
GROUP BY Ten_Khu_Vuc, Khu_Vuc_Order, nam;


/* --- 4. TÍNH TOÁN VÀ THỐNG KÊ (DÙNG COMMON TABLE EXPRESSIONS) --- */

-- CTE 1: Xử lý báo cáo tổng hợp khu vực (Phần 1)
;WITH Pivot_Data AS (
    SELECT 
        Ten_Khu_Vuc AS MAKV,
        Khu_Vuc_Order,
        SUM(CASE WHEN nam = @Nam_Ky_Goc THEN kltieuthu ELSE 0 END) AS TH_GOC,
        SUM(CASE WHEN nam = @Nam_So_Sanh THEN kltieuthu ELSE 0 END) AS TH_SANH
    FROM #raw_data
    GROUP BY Ten_Khu_Vuc, Khu_Vuc_Order
),
Calculated_Data AS (
    SELECT 
        1 AS section_order, -- Báo cáo tổng hợp nằm ở phần 1
        1 AS sort_order,
        Khu_Vuc_Order,
        MAKV,
        TH_GOC,
        TH_SANH,
        (TH_SANH - TH_GOC) AS CHENH,
        CASE WHEN TH_GOC = 0 THEN 0 ELSE (100.0 * (TH_SANH - TH_GOC) / TH_GOC) END AS TANGTRUONG
    FROM Pivot_Data

    UNION ALL

    SELECT 
        1 AS section_order,
        2 AS sort_order,
        7 AS Khu_Vuc_Order,
        N'⭐ TỔNG CỘNG (BWACO) ⭐' AS MAKV,
        SUM(TH_GOC) AS TH_GOC,
        SUM(TH_SANH) AS TH_SANH,
        SUM(TH_SANH - TH_GOC) AS CHENH,
        CASE WHEN SUM(TH_GOC) = 0 THEN 0 ELSE (100.0 * SUM(TH_SANH - TH_GOC) / SUM(TH_GOC)) END AS TANGTRUONG
    FROM Pivot_Data
),

-- CTE 2: Xử lý Top 10 khách hàng lớn nhất của từng khu vực (Phần 2)
Pivot_Customer AS (
    SELECT 
        Ten_Khu_Vuc,
        Khu_Vuc_Order,
        Ma_Khach_Hang,
        Ten_Khach_Hang,
        SUM(CASE WHEN nam = @Nam_Ky_Goc THEN kltieuthu ELSE 0 END) AS KH_GOC,
        SUM(CASE WHEN nam = @Nam_So_Sanh THEN kltieuthu ELSE 0 END) AS KH_SANH
    FROM #customer_data
    GROUP BY Ten_Khu_Vuc, Khu_Vuc_Order, Ma_Khach_Hang, Ten_Khach_Hang
),
Ranked_Customer AS (
    SELECT 
        2 AS section_order, -- Danh sách khách hàng nằm ở phần 2
        Khu_Vuc_Order,
        ROW_NUMBER() OVER (PARTITION BY Ten_Khu_Vuc ORDER BY KH_SANH DESC) AS Top_No, -- Xếp hạng theo sản lượng kỳ so sánh
        CONCAT(N'   [Top ', ROW_NUMBER() OVER (PARTITION BY Ten_Khu_Vuc ORDER BY KH_SANH DESC), N'] - ', Ma_Khach_Hang, N' - ', Ten_Khach_Hang) AS Danh_Muc,
        KH_GOC,
        KH_SANH,
        (KH_SANH - KH_GOC) AS CHENH,
        CASE WHEN KH_GOC = 0 THEN 0 ELSE (100.0 * (KH_SANH - KH_GOC) / KH_GOC) END AS TANGTRUONG,
        Ten_Khu_Vuc
    FROM Pivot_Customer
),

-- Dòng tiêu đề phân cách giữa báo cáo và danh sách khách hàng
Tieu_De_Phan_Doan AS (
    SELECT 
        2 AS section_order,
        Khu_Vuc_Order,
        0 AS Top_No,
        UPPER(CONCAT(N'=== TOP 10 KHÁCH HÀNG TIÊU THỤ LỚN NHẤT KHU VỰC: ', Ten_Khu_Vuc, N' ===')) AS Danh_Muc,
        NULL AS KH_GOC,
        NULL AS KH_SANH,
        NULL AS CHENH,
        NULL AS TANGTRUONG
    FROM #raw_data
    GROUP BY Ten_Khu_Vuc, Khu_Vuc_Order
),

-- Gộp chung tất cả các phần dữ liệu lại
Final_Union AS (
    SELECT 
        section_order, sort_order, Khu_Vuc_Order, 
        MAKV AS [Danh_Muc], TH_GOC, TH_SANH, CHENH, TANGTRUONG 
    FROM Calculated_Data
    
    UNION ALL
    
    SELECT 
        section_order, 1 AS sort_order, Khu_Vuc_Order, 
        Danh_Muc, KH_GOC, KH_SANH, CHENH, TANGTRUONG 
    FROM Tieu_De_Phan_Doan

    UNION ALL
    
    SELECT 
        section_order, 2 AS sort_order, Khu_Vuc_Order, 
        Danh_Muc, KH_GOC, KH_SANH, CHENH, TANGTRUONG 
    FROM Ranked_Customer 
    WHERE Top_No <= 10 -- Lấy đúng 10 khách hàng lớn nhất
)

/* --- 5. ĐỊNH DẠNG VÀ KẾT XUẤT BÁO CÁO TOÀN DIỆN --- */
SELECT
    Danh_Muc AS [Danh Mục Khu Vực / Khách Hàng Top],
    CASE WHEN TH_GOC IS NULL THEN '' ELSE FORMAT(TH_GOC, '#,##0', 'vi-VN') END AS [Thực Hiện Kỳ Gốc],
    CASE WHEN TH_SANH IS NULL THEN '' ELSE FORMAT(TH_SANH, '#,##0', 'vi-VN') END AS [Thực Hiện Kỳ So Sánh],
    CASE 
        WHEN CHENH IS NULL THEN ''
        WHEN CHENH > 0 THEN CONCAT('+', FORMAT(CHENH, '#,##0', 'vi-VN')) 
        ELSE FORMAT(CHENH, '#,##0', 'vi-VN') 
    END AS [Tăng Giảm (+/-)],
    CASE  
        WHEN TANGTRUONG IS NULL THEN ''
        WHEN TANGTRUONG > 0 THEN CONCAT('+', FORMAT(TANGTRUONG, '0.00', 'vi-VN'), ' %') 
        WHEN TANGTRUONG = 0 THEN '0,00 %' 
        ELSE CONCAT(FORMAT(TANGTRUONG, '0.00', 'vi-VN'), ' %') 
    END AS [% Tăng Trưởng],
    CASE 
        WHEN TH_GOC IS NULL AND TH_SANH IS NULL THEN N'⚙️ PHÂN TÍCH CHUYÊN SÂU'
        WHEN Danh_Muc LIKE N'%TỔNG CỘNG%' AND CHENH > 0 THEN N'🔥 PHÁT TRIỂN MẠNH' 
        WHEN CHENH > 0 THEN N'📈 Tăng trưởng tốt' 
        WHEN CHENH < 0 THEN N'📉 Sụt giảm sản lượng' 
        ELSE N'➖ Ổn định' 
    END AS [Đánh Giá Trạng Thái]
FROM Final_Union 
ORDER BY 
    section_order ASC,   -- Hiện bảng tổng hợp (1) trước, danh sách khách hàng (2) sau
    Khu_Vuc_Order ASC,   -- Sắp xếp thứ tự khu vực: Vũng Tàu -> Bà Rịa -> Long Điền -> Xuyên Mộc -> Châu Đức
    sort_order ASC,      -- Tiêu đề phân đoạn hiện trước, dữ liệu chi tiết hiện sau
    TH_SANH DESC;        -- Xếp khách hàng tiêu thụ nhiều nhất lên trên

/* DỌN DẸP BẢNG TẠM CHỐNG RÁC HỆ THỐNG */
IF OBJECT_ID('tempdb..#raw_data') IS NOT NULL DROP TABLE #raw_data;
IF OBJECT_ID('tempdb..#tbl_ds_makv') IS NOT NULL DROP TABLE #tbl_ds_makv;
IF OBJECT_ID('tempdb..#tbl_ds_makh_chi_lay') IS NOT NULL DROP TABLE #tbl_ds_makh_chi_lay;
IF OBJECT_ID('tempdb..#tbl_ds_makh_loai') IS NOT NULL DROP TABLE #tbl_ds_makh_loai;
IF OBJECT_ID('tempdb..#customer_data') IS NOT NULL DROP TABLE #customer_data;
SET NOCOUNT OFF;
GO