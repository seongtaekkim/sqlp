import oracle.jdbc.driver.OracleConnection;

import java.sql.*;

public class App {
    static Connection conn;
    public static void main(String[] args) {
        try {
            Class.forName("oracle.jdbc.driver.OracleDriver");
            String url = "jdbc:oracle:thin:@localhost:1521:xe";
            String id ="sys as sysdba";
            String pass = "pass";
            conn = DriverManager.getConnection(url, id, pass);
            System.out.println(conn);

            String sql = "select count(*) from emp";
            PreparedStatement ps = conn.prepareStatement(sql);

            prePareNoBinding(100);
            preNoCaching(100);
            preCursorHoding(100);
            preCursorCaching(100);

        } catch (ClassNotFoundException e) {
            throw new RuntimeException(e);
        } catch (SQLException e) {
            throw new RuntimeException(e);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    static void prePareNoBinding(int cnt)throws Exception{
        PreparedStatement pstmt = null;
        ResultSet rs = null;

        for( int i = 0; i < cnt; i ++){
            pstmt = conn.prepareStatement(" SELECT /* prePareNoBinding */ "+i+","+i+" ,'test' ,a.* FROM EMP a WHERE a.ENAME LIKE 'W%' ");
            rs = pstmt.executeQuery();

            rs.close();
            pstmt.close();
        }
    }

    static void preNoCaching(int cnt)throws Exception{
        PreparedStatement pstmt = null;
        ResultSet rs = null;

        for( int i = 0; i < cnt; i ++){
            pstmt = conn.prepareStatement(" SELECT /* preNoCaching */a.* ,?, ?, ? FROM EMP a WHERE a.ENAME LIKE 'W%' ");
            pstmt.setInt(1, i);
            pstmt.setInt(2, i);
            pstmt.setString(3, "test");
            rs = pstmt.executeQuery();

            rs.close();
            pstmt.close();
        }
    }

    static void preCursorHoding(int cnt)throws Exception{
        PreparedStatement pstmt = null;
        ResultSet rs = null;
        pstmt = conn.prepareStatement(" SELECT /* preCursorHoding */ a.* ,?, ?, ? FROM EMP a WHERE a.ENAME LIKE 'W%' ");

        for( int i = 0; i < cnt; i ++){
            pstmt.setInt(1, i);
            pstmt.setInt(2, i);
            pstmt.setString(3, "test");
            rs = pstmt.executeQuery();
            rs.close();
        }
        pstmt.close();
    }

    static void preCursorCaching(int cnt)throws Exception{
        ((OracleConnection)conn).setStatementCacheSize(1);
        ((OracleConnection)conn).setImplicitCachingEnabled(true);

        for( int i = 0; i < cnt; i ++){
            PreparedStatement pstmt = conn.prepareStatement(" SELECT /* preCursorCaching */ a.* ,?, ?, ? FROM EMP a WHERE a.ENAME LIKE 'W%' ");
            pstmt.setInt(1, i);
            pstmt.setInt(2, i);
            pstmt.setString(3, "test");
            ResultSet rs = pstmt.executeQuery();
            rs.close();
            pstmt.close();
        }
    }

}
