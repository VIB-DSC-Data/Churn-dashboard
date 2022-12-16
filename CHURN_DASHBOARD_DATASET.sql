
--------------------------------------------------------
----------------------LOGIN TABLE ----------------------

create table MY_CHURN_DASHBOARD_LOGIN AS
select DISTINCT(client_no) AS CLIENT_NO  
, last_day(sym_run_date) as datetime 
from (
select 
		CAST(CLIENT_NO AS VARCHAR(20)) AS CLIENT_NO
		,SYM_RUN_DATE
		FROM DEC_BU.U_PRO_ACTIVITY 
		WHERE SYM_RUN_DATE between  DATE'2022-06-01'  and  DATE'2022-11-30'  
		UNION ALL 
		SELECT 
		CAST(CLIENT_NO AS VARCHAR(20)) AS CLIENT_NO 
		,SYM_RUN_DATE 
		FROM U_ACTIVE_CLIENT_MB2 
		WHERE SYM_RUN_DATE between  DATE'2022-06-01'  and  DATE'2022-11-30'  
		)


---------------------------------------------------------
-------------- TABLE DETAIL - CLIENT_NO LEVEL ------------

insert into  MY_CHURN_DASHBOARD_DETAIL 
		WITH TYPE_LV1 AS
		(
            SELECT  date'2022-10-31'  as datetime 
            ,A.CLIENT_NO 
            ,A.IB_REGISTER_DATE
            ,B.CLIENT_NO AS NEW_ACQUIRE_CLASSIFY
            ,CASE 
                WHEN last_day(IB_REGISTER_DATE) =  date'2022-10-31'  then 'New_accquired_user' 
                WHEN A.CLIENT_NO = B.CLIENT_NO then 'Active_user' 
                WHEN  B.CLIENT_NO IS NULL AND  IB_REGISTER_DATE <  date'2022-10-01' THEN 'Inactive_user' 
                END AS TYPE_LV1  
            FROM 
            (
                select CLIENT_NO 
                , CASE WHEN IB_REGISTERED_DATE2 IS NOT NULL AND IB_REGISTER_DATE IS NOT NULL AND IB_REGISTERED_DATE2 > IB_REGISTER_DATE  THEN IB_REGISTER_DATE
                WHEN IB_REGISTERED_DATE2 IS NOT NULL AND IB_REGISTER_DATE IS NOT NULL AND IB_REGISTERED_DATE2 < IB_REGISTER_DATE  THEN IB_REGISTERED_DATE2 
                WHEN IB_REGISTERED_DATE2 IS NULL THEN IB_REGISTER_DATE 
                WHEN IB_REGISTER_DATE IS NULL THEN IB_REGISTERED_DATE2 
                END AS IB_REGISTER_DATE    
                from u_tableau_customer 
                where ebank_type != 'NON_EBANK' 
            ) A
            LEFT JOIN 
            (
                SELECT * FROM 
                MY_CHURN_DASHBOARD_LOGIN 
                WHERE DATETIME =  date'2022-10-31'  
            ) B
            ON A.CLIENT_NO = B.CLIENT_NO 
        )
		,WON_BACK_USER AS 
		(
            SELECT A.CLIENT_NO 
            , CASE WHEN A.CLIENT_NO = B.CLIENT_NO THEN 'LOYAL' ELSE 'WON_BACK_USER' END TYPE_LV2 
            FROM 
            (
                SELECT * FROM 
            MY_CHURN_DASHBOARD_LOGIN 
            WHERE DATETIME =  date'2022-10-31'  
            ) A
            LEFT JOIN (
                SELECT * FROM 
            MY_CHURN_DASHBOARD_LOGIN 
            WHERE DATETIME = date'2022-09-30'
            ) B
            ON A.CLIENT_NO = B.CLIENT_NO 
        )
        ,LOST_USER AS 
        (
                SELECT A.CLIENT_NO 
                , CASE WHEN A.CLIENT_NO = B.CLIENT_NO THEN 'LOYAL' ELSE 'LOST_USERS' END TYPE_LV2
            FROM 
            (
                SELECT * FROM 
            MY_CHURN_DASHBOARD_LOGIN 
            WHERE DATETIME = date'2022-09-30'
            ) A
            LEFT JOIN (
                SELECT * FROM 
            MY_CHURN_DASHBOARD_LOGIN 
            WHERE DATETIME =  date'2022-10-31'  ) B
            ON A.CLIENT_NO = B.CLIENT_NO
        )    
		SELECT 
		A.DATETIME
		,A.CLIENT_NO
        ,A.IB_REGISTER_DATE
		,A.TYPE_LV1
		, CASE WHEN A.TYPE_LV1 = 'Active_user'  AND A1.TYPE_LV2 = 'WON_BACK_USER' AND A.IB_REGISTER_DATE < date'2022-07-01' THEN 'wonback_users'
               WHEN A.TYPE_LV1 = 'Active_user'   THEN  'loyal_active_user' --AND A1.TYPE_LV2 = 'LOYAL_ACTIVE_USER'
               WHEN A.TYPE_LV1 = 'New_accquired_user' AND A.CLIENT_NO = A.NEW_ACQUIRE_CLASSIFY THEN 'active_new_accquired_user'  ---
               WHEN A.TYPE_LV1 = 'New_accquired_user' AND A.NEW_ACQUIRE_CLASSIFY IS null then 'inactive_new_accquired_user' 
               WHEN A.TYPE_LV1 = 'Inactive_user'  AND A2.TYPE_LV2 = 'LOST_USERS'  THEN 'lost_users'
               WHEN A.TYPE_LV1 = 'Inactive_user'  THEN  'hibernated_user' 
               END AS TYPE_LV2   
		FROM TYPE_LV1 A 
		LEFT JOIN WON_BACK_USER A1
		ON A.CLIENT_NO = A1.CLIENT_NO 
		LEFT JOIN LOST_USER A2
		ON A.CLIENT_NO = A2.CLIENT_NO 
		LEFT JOIN      
		(SELECT CLIENT_NO FROM 
            MY_CHURN_DASHBOARD_LOGIN 
            WHERE DATETIME =  date'2022-10-31'  ) A3
        ON A.CLIENT_NO = A3.CLIENT_NO 
		
------------------------------------------------------------	
------------------- ONL TRANSACTION ------------------------

	INSERT INTO MY_CHURN_DASHBOARD_ONLTRANS 
	select      date'2022-01-31'as datetime 
	,CLIENT_NO   
		,SUM(TOTAL_TRANS) AS  TOTAL_TRANS		
		,SUM(TOTAL_AMT) AS 	  TOTAL_AMT
		FROM 
		(
		select A.client_no
		,SUM(case when LAST_DAY(TRANSDATE) =      date'2022-01-31'THEN 1 ELSE 0 END) TOTAL_TRANS
		,SUM(case when LAST_DAY(TRANSDATE) =      date'2022-01-31'THEN TRANSAMOUNT ELSE 0 END) TOTAL_AMT
		FROM dec_bu.u_pro_online_transaction A
		--WHERE trans_lv1 like '%Transfer%' 
		group by A.client_no 
		UNION ALL 
		SELECT A.CLIENT_NO 
		,SUM(case when LAST_DAY(TRAN_DATE) =      date'2022-01-31'THEN 1 ELSE 0 END) TOTAL_TRANS		
		,SUM(case when LAST_DAY(TRAN_DATE) =      date'2022-01-31'THEN TRAN_AMOUNT ELSE 0 END) TOTAL_AMT
		FROM DEC_BU.U_PROD_FT_TRAN_LOG A	
		--WHERE trans_lv1 like '%Transfer%' 
		group by A.client_no )
		group by client_no 	
			
--------------------------------------------------------------		
-------------------------- FINAL TABLE -----------------------

	SELECT A.*,CASE WHEN  A1.TOTAL_AMT IS NULL OR  A1.TOTAL_AMT = 0 THEN 'nontransactional' else 'transactional' end as TYPE_LV3
             ,A1.TOTAL_AMT, A1.TOTAL_TRANS
            FROM DEC_BU.MY_CHURN_DASHBOARD_DETAIL A
            LEFT JOIN DEC_BU.MY_CHURN_DASHBOARD_ONLTRANS A1
            ON A.CLIENT_NO = A1.CLIENT_NO AND A.DATETIME = A1.DATETIME
              WHERE A.TYPE_LV1 IS NOT NULL
