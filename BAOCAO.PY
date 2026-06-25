import streamlit as st
import pandas as pd
import pyodbc
# ============================================================================
# 1. CẤU HÌNH GIAO DIỆN MENU TRÊN WEB (STREAMLIT)
# ============================================================================
st.set_page_config(page_title="BWACO - Báo Cáo Sản Lượng", layout="wide")
st.title("📊 BÁO CÁO ĐỘNG SO SÁNH NƯỚC THƯƠNG PHẨM CÙNG KỲ")

# Tạo thanh Menu chọn thông số ở bên lề trái (Sidebar)
st.sidebar.header("🛠️ BỘ LỌC TÙY CHỌN")
thang_chon = st.sidebar.selectbox("1. Chọn Tháng Muốn Xem:", list(range(1, 13)), index=4) # Mặc định là tháng 5
nam_goc = st.sidebar.number_input("2. Chọn Năm Gốc:", value=2025)
nam_sanh = st.sidebar.number_input("3. Chọn Năm So Sánh:", value=2026)

# ============================================================================
# 2. KẾT NỐI DATABASE VÀ TRUY XUẤT DỮ LIỆU ĐỘNG
# ============================================================================
SERVER_NAME = "192.168.20.211" 
DATABASE_NAME = "EOSVT_STANDBY"

@st.cache_data # Bộ nhớ đệm giúp bấm Menu đổi tháng nhảy số ngay lập tức
def lay_data_tu_sql(thang, nam1, nam2):
    # Đã chuyển sang Driver tiêu chuẩn để máy nào trong mạng nội bộ cũng chạy được
    conn_str = (
        f"DRIVER={{SQL Server}};"
        f"SERVER={SERVER_NAME};"
        f"DATABASE={DATABASE_NAME};"
        f"UID=sa;PWD=xemdulieu;"
    )
    
    conn = pyodbc.connect(conn_str)
    
    query = f"""
    SELECT 
        tt.nam,
        CASE 
            WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('VT', 'VNGTAU') THEN N'Vũng Tàu'
            WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('BR', 'BRIA')   THEN N'Bà Rịa'
            WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('LD', 'LDIEN')  THEN N'Long Điền'
            WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('XM', 'XMOC')   THEN N'Xuyên Mộc'
            WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('CD', 'CDUC')   THEN N'Châu Đức'
            ELSE N'Khu vực khác'
        END AS MAKV,
        SUM(ISNULL(tt.kltieuthu, 0)) AS kltieuthu
    FROM {DATABASE_NAME}.dbo.tieuthu tt
    LEFT JOIN {DATABASE_NAME}.dbo.khachhang kh ON tt.IDKH = kh.IDKH
    WHERE tt.thang = {thang} AND tt.nam IN ({nam1}, {nam2}) AND (tt.ishuy IS NULL OR tt.ishuy = 0)
    GROUP BY 
        tt.nam,
        CASE 
            WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('VT', 'VNGTAU') THEN N'Vũng Tàu'
            WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('BR', 'BRIA')   THEN N'Bà Rịa'
            WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('LD', 'LDIEN')  THEN N'Long Điền'
            WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('XM', 'XMOC')   THEN N'Xuyên Mộc'
            WHEN UPPER(LTRIM(RTRIM(kh.MAKV))) IN ('CD', 'CDUC')   THEN N'Châu Đức'
            ELSE N'Khu vực khác'
        END;
    """
    df = pd.read_sql(query, conn)
    conn.close()
    return df

# ============================================================================
# 3. TỰ ĐỘNG TÍNH TOÁN VÀ THỂ HIỆN LÊN GIAO DIỆN WEB
# ============================================================================
try:
    # Chạy lệnh gọi dữ liệu thô
    raw_df = lay_data_tu_sql(thang_chon, nam_goc, nam_sanh)
    
    if not raw_df.empty:
        # Xoay trục dữ liệu (Pivot) từ hàng dọc thành 2 cột năm để so sánh
        pivot_df = raw_df.pivot(index='MAKV', columns='nam', values='kltieuthu').fillna(0)
        
        # ĐẢM BẢO CẢ 2 CỘT NĂM ĐỀU TỒN TẠI TRONG PIVOT (Nếu thiếu tự động bù cột 0)
        if nam_goc not in pivot_df.columns: 
            pivot_df[nam_goc] = 0.0
        if nam_sanh not in pivot_df.columns: 
            pivot_df[nam_sanh] = 0.0
        
        # Tính toán chênh lệch
        pivot_df['CHENH'] = pivot_df[nam_sanh] - pivot_df[nam_goc]
        pivot_df['TANGTRUONG'] = (pivot_df['CHENH'] / pivot_df[nam_goc] * 100).fillna(0)
        
        # Tính dòng Tổng cộng cho toàn hệ thống BWACO
        tong_goc = pivot_df[nam_goc].sum()
        tong_sanh = pivot_df[nam_sanh].sum()
        tong_chenh = tong_sanh - tong_goc
        tong_truong = (tong_chenh / tong_goc * 100) if tong_goc != 0 else 0
        
        # Đẩy dòng Tổng cộng vào cuối bảng
        pivot_df.loc['⭐ TỔNG CỘNG (BWACO) ⭐'] = [tong_goc, tong_sanh, tong_chenh, tong_truong]
        
        # Sao chép và định dạng lại số liệu
        report_df = pivot_df.copy()
        report_df[nam_goc] = pd.to_numeric(report_df[nam_goc], errors='coerce').fillna(0).map('{:,.0f}'.format)
        report_df[nam_sanh] = pd.to_numeric(report_df[nam_sanh], errors='coerce').fillna(0).map('{:,.0f}'.format)
        report_df['CHENH'] = pd.to_numeric(report_df['CHENH'], errors='coerce').fillna(0).map('{:+,.0f}'.format)
        report_df['TANGTRUONG'] = pd.to_numeric(report_df['TANGTRUONG'], errors='coerce').fillna(0).map('{:+.2f} %'.format)
        
        # Đổi tên tiêu đề các cột hiển thị trên Web
        report_df.columns = [f'Thực Hiện Kỳ Gốc ({nam_goc})', f'Thực Hiện Kỳ So Sánh ({nam_sanh})', 'Tăng Giảm (+/-)', '% Tăng Trưởng']
        
        # Xuất bảng dữ liệu ra màn hình chính
        st.write(f"### 📋 Kết quả đối chiếu sản lượng Thương Phẩm - Tháng {thang_chon}")
        st.dataframe(report_df, use_container_width=True)
        
        # Thiết kế thêm 3 ô Thẻ thông số (KPI Cards)
        st.write("---")
        col1, col2, col3 = st.columns(3)
        col1.metric(f"Tổng Sản Lượng Kỳ Gốc ({nam_goc})", f"{tong_goc:,.0f} m³")
        col2.metric(f"Tổng Sản Lượng So Sánh ({nam_sanh})", f"{tong_sanh:,.0f} m³", f"{tong_truong:+.2f}%")
        
        with col3:
            st.write("**Trạng Thái Hệ Thống:**")
            if tong_chenh > 0:
                st.success(f"🔥 PHÁT TRIỂN MẠNH MẼ \n\n Tăng: {tong_chenh:+,.0f} m³")
            elif tong_chenh < 0:
                st.error(f"📉 SẢN LƯỢNG SỤT GIẢM \n\n Giảm: {tong_chenh:+,.0f} m³")
            else:
                st.info("➖ SẢN LƯỢNG ỔN ĐỊNH")
                
    else:
        st.info(f"Không tìm thấy số liệu tiêu thụ nào của Tháng {thang_chon} trong database.")

except Exception as e:
    st.error(f"Lỗi hệ thống chi tiết: {e}")
    st.info("💡 Mẹo: Hãy kiểm tra dây mạng LAN/Wifi xem có cùng dải mạng với Server 192.168.20.211 không nhé!")