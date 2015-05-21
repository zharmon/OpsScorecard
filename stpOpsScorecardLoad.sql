/* **************************************************************************
 * Description:  LOAD EMPLOYEE DATA TO FactEmployeeScorecard TO STAGE DATA FOR OPS SCORECARD REPORTING

 * Version Date: 1/20/2015				User: ZACH HARMON		

 ************************************************************************** */

USE FinanceDataMart
GO

IF EXISTS (SELECT NAME FROM sysobjects WHERE  name=N'stpOpsScorecardLoad' AND type='P')
	DROP PROCEDURE stpOpsScorecardLoad
GO

CREATE PROCEDURE stpOpsScorecardLoad
@Period AS INT   --- The only paramater that we're passing through for this Proc is Period
AS

----For testing only
--DECLARE @Period INT            --- uncomment for testing
--SET @Period = 201409

DECLARE @StartDateINT INT,   --- FIRST DAY OF THE PERIOD THAT YOU ARE PASSING THROUGH
        @EndDateINT INT,     --- LAST DAY OF THE PERIOD THAT YOU ARE PASSING THROUGH
        @StartDate smalldatetime,  --- FIRST DAY OF THE FIRST DAY OF THE YEAR OF THE PERIOD THAT YOU'RE PASSING THROUGH		
		@StartPeriod INT, --- FIRST PERIOD OF THE YEAR OF THE PERIOD THAT YOU'RE PASSING THROUGH
		@StartDatePeriod smalldatetime, --- FIRST DAY OF THE PERIOD THAT YOU ARE PASSING THROUGH
		@EndDate smalldatetime,   --- LAST DAY OF THE PERIOD THAT YOU ARE PASSING THROUGH
		@MonthStartDate smalldatetime,  --- DATE FORM OF @StartDateINT
		@MonthEndDate smalldatetime,  --- DATE FORM OF @EndDateINT
		@StartDayID INT,  --- DAYID FORM OF @StartDateINT
        @EndDayID INT, --- DAYID  FORM OF @EndDateINT
		@Q1StartPeriod INT, --- FIRST MONTH OF MOST COMPLETED QUARTER TWO QUARTERS IN ARREARS
		@Q1EndPeriod INT, --- LAST MONTH OF MOST COMPLETED QUARTER TWO QUARTERS IN ARREARS
		@Q2StartPeriod INT, --- FIRST MONTH OF MOST COMPLETED PRIOR QUARTER 
		@Q2EndPeriod INT, --- LAST MONTH OF MOST COMPLETED PRIOR QUARTER 
		@Q1MinDate smalldatetime,  --- MINIMUM DATE OF THE QUARTER, TWO QUARTERS IN ARREARS. 
        @Q1MaxDate smalldatetime,  --- MAXIMUM DATE OF THE QUARTER, TWO QUARTERS IN ARREARS. 
        @Q2MinDate smalldatetime,  --- MINIMUM DATE OF THE QUARTER, ONE QUARTERS IN ARREARS. 
        @Q2MaxDate smalldatetime,  --- MAXIMUM DATE OF THE QUARTER, ONE QUARTERS IN ARREARS. 
		@PeriodMonth INT  --- MONTH OF THE PERIOD THAT YOURE PASSING THROUGH


SELECT @StartDateINT = min(DateID),
       @EndDateINT =   max(DateID),
       @EndDate = max(date),
	   @StartDatePeriod = min(date)
FROM dbo.tblTime 
WHERE Period = @Period

SELECT  @MonthStartDate = DATE,
        @StartDayID = DayID
FROM    dbo.tblTime 
WHERE   DateID = @StartDateINT

SELECT @MonthEndDate = DATE,
       @EndDayID =  DayID
FROM   dbo.tblTime 
WHERE  DateID = @EndDateINT


SET @StartPeriod =  (SELECT MIN(Period)
                     FROM dbo.tblTime 
                     WHERE YEAR = (SELECT Year
                                   FROM dbo.tblTime 
                                   WHERE Period = @Period
                                   GROUP BY Year)
                    )

SET @StartDate = (SELECT MIN(Date)
                  FROM dbo.tblTime
                  WHERE Period = @StartPeriod
				  )


SET @PeriodMonth = RIGHT(@Period,2)
SET @Q1StartPeriod = (SELECT CASE WHEN @PeriodMonth = 1 THEN @Period-94
                                                         WHEN @PeriodMonth = 2 THEN @Period-95
                                                         WHEN @PeriodMonth = 3 THEN @Period-96
                                                         WHEN @PeriodMonth = 4 THEN @Period-94
                                  WHEN @PeriodMonth = 5 THEN @Period-95
                                                         WHEN @PeriodMonth = 6 THEN @Period-96
                                                         WHEN @PeriodMonth = 7 THEN @Period-6
                                                         WHEN @PeriodMonth = 8 THEN @Period-7
                                                         WHEN @PeriodMonth = 9 THEN @Period-8
                                                         WHEN @PeriodMonth = 10 THEN @Period-6
                                                         WHEN @PeriodMonth = 11 THEN @Period-7
                                                         WHEN @PeriodMonth = 12 THEN @Period-8
                       END)

SET @Q1EndPeriod =   @Q1StartPeriod+2 
SET @Q2StartPeriod = CASE WHEN @PeriodMonth IN (1,2,3) THEN @Q1EndPeriod+1
                          WHEN @PeriodMonth IN (4,5,6) THEN @Q1EndPeriod +89
                          WHEN @PeriodMonth IN (7,8,9) THEN @Q1EndPeriod+1
                          WHEN @PeriodMonth IN (10,11,12) THEN @Q1EndPeriod+1
                     END
SET @Q2EndPeriod =   @Q2StartPeriod+2


SET @Q1MinDate = (SELECT min(date) FROM dbo.tbltime WHERE Period = @Q1StartPeriod)
SET @Q1MaxDate = (SELECT max(date) FROM dbo.tbltime WHERE Period = @Q1EndPeriod)  
SET @Q2MinDate = (SELECT min(date) FROM dbo.tbltime WHERE Period = @Q2StartPeriod)  
SET @Q2MaxDate = (SELECT max(date) FROM dbo.tbltime WHERE Period = @Q2EndPeriod)  


/*
 --- FOR TESTING PURPOSES
*/
--SELECT  @StartDateINT StartDateINT,
--        @EndDateINT EndDateINT,
--        @StartDate StartDate,
--		@StartPeriod StartPeriod,
--      @StartDatePeriod StartDatePeriod,
--		@EndDate EndDate,
--		@MonthStartDate MonthStartDate,
--		@MonthEndDate MonthEndDate,
--		@StartDayID StartDayID,
--        @EndDayID EndDayID,
--		@Q1StartPeriod Q1StartPeriod,
--		@Q1EndPeriod Q1EndPeriod,
--		@Q2StartPeriod Q2StartPeriod,
--		@Q2EndPeriod Q2EndPeriod,
--		@Q1MinDate Q1MinDate,
--		@Q1MaxDate Q1MaxDate,
--		@Q2MinDate Q2MinDate,
--		@Q2MaxDate Q2MaxDate,
--		@PeriodMonth PeriodMonth


/* THIS SECTION DROPS ALL OF THE TEMP TABLES THAT WE CREATE*/

IF OBJECT_ID('tempdb..#tblDailyMeasuresCalc') IS NOT NULL
    DROP TABLE #tblDailyMeasuresCalc

IF OBJECT_ID('tempdb..#tblGLDataCalc') IS NOT NULL
    DROP TABLE #tblGLDataCalc

IF OBJECT_ID('tempdb..#Regions') IS NOT NULL
    DROP TABLE #Regions

IF OBJECT_ID('tempdb..#SubRegions') IS NOT NULL
    DROP TABLE #SubRegions

IF OBJECT_ID('tempdb..#Patches') IS NOT NULL
    DROP TABLE #Patches

IF OBJECT_ID('tempdb..#Company') IS NOT NULL
    DROP TABLE #Company

IF OBJECT_ID('tempdb..#ActualSales') IS NOT NULL
    DROP TABLE #ActualSales

IF OBJECT_ID('tempdb..#ProjectedSales') IS NOT NULL
    DROP TABLE #ProjectedSales

IF OBJECT_ID('tempdb..#NINETY_DAY_TURNOVER') IS NOT NULL
    DROP TABLE #NINETY_DAY_TURNOVER

IF OBJECT_ID('tempdb..#INT_HIRE_PCT') IS NOT NULL
    DROP TABLE #INT_HIRE_PCT

IF OBJECT_ID('tempdb..#FactEmployeeDataCTE') IS NOT NULL
    DROP TABLE #FactEmployeeDataCTE

IF OBJECT_ID('tempdb..#RVT') IS NOT NULL
    DROP TABLE #RVT

IF OBJECT_ID('tempdb..#TIMEINPOS') IS NOT NULL
    DROP TABLE #TIMEINPOS



--- WE PRE-AGGREGATE ALL OF THE METRICS THAT COME FROM tblGLData IN AN EFFORT TO NOT QUERY AGAINST THE ENTIRE TABLE EVERY TIME WE NEED A METRIC
SELECT
       FKEntityID
       ,Period
       ,CASE WHEN FKAccountID = 828 THEN Amount END AS FKAccountID828
       ,CASE WHEN FKAccountID = 829 THEN Amount END AS FKAccountID829
       ,CASE WHEN FKAccountID = 830 THEN Amount END AS FKAccountID830
       ,CASE WHEN FKAccountID = 834 THEN Amount END AS FKAccountID834
       ,CASE WHEN FKAccountID = 835 THEN Amount END AS FKAccountID835
       ,CASE WHEN FKAccountID = 839 THEN Amount END AS FKAccountID839
       ,CASE WHEN FKAccountID = 840 THEN Amount END AS FKAccountID840
       ,CASE WHEN FKAccountID = 841 THEN Amount END AS FKAccountID841
       ,CASE WHEN FKAccountID = 842 THEN Amount END AS FKAccountID842
       ,CASE WHEN FKAccountID = 843 THEN Amount END AS FKAccountID843
       ,CASE WHEN FKAccountID = 844 THEN Amount END AS FKAccountID844
       ,CASE WHEN FKAccountID = 846 THEN Amount END AS FKAccountID846
       ,CASE WHEN FKAccountID = 847 THEN Amount END AS FKAccountID847
       ,CASE WHEN FKAccountID = 848 THEN Amount END AS FKAccountID848
INTO #tblGLDataCalc
FROM dbo.tblGLData
WHERE FKAccountID IN (828,829,830,834,835,839,840,841,842,843,844,846,847,848)
       AND FKDataVersionID = 0
       AND Period = @Period

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_EntityPeriod
ON #tblGLDataCalc (FKEntityID, Period)


--- WE PRE-AGGREGATE ALL OF THE METRICS THAT COME FROM tblDailyMeasuresData IN AN EFFORT TO NOT QUERY AGAINST THE ENTIRE TABLE EVERY TIME WE NEED A METRIC
Select DMC.FKEntityID,      
       @Period as Period,                 
       CASE WHEN DMC.AtModelPercent >= .90 THEN 1 ELSE 0 END AS FKAccountID93                    
INTO #tblDailyMeasuresCalc                              
FROM                       
(select  eh.entitylevel3 as Region,                           
         eh.EntityLevel8 as Restaurant,                       
         eh.FKEntityID,                  
         
         Sum(dmd.amount)/Count(dmd.amount) AtModelPercent                          
from     financedatamart.dbo.tbldailymeasuresdata dmd                      
         INNER JOIN FinanceDataMart.dbo.tbltime t                          
         ON dmd.fkdayid = t.dayid          
         AND t.DateID BETWEEN @StartDateINT AND @EndDateINT        
         INNER JOIN FinanceDataMart.dbo.tblEntityHierarchy eh         
         ON dmd.FKEntityID = eh.FKEntityID        
where    dmd.fkdailymeasureid = 93                     
         AND dmd.fkdataversionid =0                           
Group BY eh.entitylevel3,                
         eh.EntityLevel8,                
         eh.FKEntityID                   
) DMC

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_EntityPeriod
 ON #tblDailyMeasuresCalc (FKEntityID, Period)




--- TEMP TABLE THAT LISTS THE OWNERS OF ALL Regions
SELECT FKRDID,
       FKEntityID
INTO #Regions
FROM dbo.tblRDAssignment 
GROUP BY FKRDID,
         FKEntityID

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_Entity
 ON #Regions (FKEntityID)

--- TEMP TABLE THAT LISTS THE OWNERS OF ALL SUB Regions THAT DONT OWN A REGION
SELECT FKODID,
       FKEntityID
INTO #SubRegions
FROM dbo.tblODAssignment
WHERE FKODID NOT IN (SELECT FKRDID
					FROM dbo.tblRDAssignment  --- CHECKING TO MAKE SURE THEY DONT OWN A REGION
			        )
GROUP BY FKODID,
        FKEntityID

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_Entity
 ON #SubRegions (FKEntityID)


--- TEMP TABLE THAT LISTS THE OWNERS OF ALL #Patches THAT DON'T OWN A REGION OR SUB REGION
SELECT  pm.FKEmployeeID,
        pm.FKEntityID
INTO #Patches
FROM dbo.tblPatchMapping pm
	INNER JOIN dbo.tblEntityHierarchy eh
	ON pm.FKEntityID = eh.FKEntityLevel7ID
	AND eh.EntityLevel7 NOT LIKE '%New Store%' --DON'T INCLUDE RESTAURANTS THAT ARE 'NEW STORES'
WHERE pm.FKEmployeeID NOT IN (SELECT FKRDID 
			 			      FROM dbo.tblRDAssignment --- CHECKING TO MAKE SURE THEY DONT OWN A REGION
			                  )
	  AND pm.FKEmployeeID NOT IN (SELECT FKODID 
							      FROM dbo.tblODAssignment --- CHECKING TO MAKE SURE THEY DONT OWN A SUB REGION
			                      )
GROUP BY pm.FKEmployeeID,
        pm.FKEntityID


--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_Entity
ON #Patches (FKEntityID)


--- TEMP TABLE THAT LISTS THE OWNERS OF ALL COMPANY
SELECT 124 as FKEmployeeID, --- 124 IS STEVE ELLS' EMPLID
       9999 as FKEntityID  
INTO #Company



---- BEGIN DELETE
---- DELETE DATA FROM THE TABLE FOR THE PERIOD THAT YOU'RE PROCESSING
DELETE factEmployeeScorecard 
FROM factEmployeeScorecard
WHERE Period = @Period

---- TEMP TABLE THAT CALCULATES THE ACTUAL SALES OF A RESTAURANT FOR USE IN ACTUAL VS. PROJECTED SALES MEASURE

SELECT	dmd.FKEntityID,
		CASE WHEN SUM(dmd.Amount) = 0 THEN NULL ELSE SUM(dmd.Amount) END as #ActualSales
INTO #ActualSales
FROM	tblDailyMeasuresData dmd
			JOIN tblTime t
			ON dmd.FKDayID = t.DayID
WHERE		dmd.FKDailyMeasureID = 11  --- ACCOUNT 11 IS ACTUAL SALES
AND			t.DateID BETWEEN @StartDateINT AND @EndDateINT
AND			dmd.Amount <> 0
AND			dmd.Amount IS NOT NULL
AND			dmd.FKDataVersionID = 0
GROUP BY	dmd.FKEntityID

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_Entity
ON #ActualSales (FKEntityID)


---- TEMP TABLE THAT CALCULATES THE PROJECTED SALES OF A RESTAURANT FOR USE IN ACTUAL VS. PROJECTED SALES MEASURE

SELECT	dmd2.FKEntityID,
		CASE WHEN SUM(dmd2.Amount) = 0 THEN NULL ELSE SUM(dmd2.Amount) END AS #ProjectedSales
INTO #ProjectedSales
FROM	tblDailyMeasuresData dmd2
		JOIN tblTime t
		ON dmd2.FKDayID = t.DayID
WHERE		dmd2.FKDailyMeasureID = 12 --- ACCOUNT 12 IS PROJECTED SALES
AND			dmd2.Amount <> 0
AND			dmd2.Amount IS NOT NULL
AND			dmd2.FKDataVersionID = 0
AND			t.DateID BETWEEN @StartDateINT AND @EndDateINT
GROUP BY	dmd2.FKEntityID

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_Entity
ON #ProjectedSales (FKEntityID)

---  TEMP TABLE THAT CALCULATES THE % OF APPRENTICES PROMOTED VS # OF TOTAL APPR/GM HIRES

SELECT A.FKEntityId,
       SUM(a.ApprPromos) as totalApprPromos,
       SUM(A.ApprPromos+A.ApprHires+A.RRHires+A.GMHires) totalHires 
INTO #INT_HIRE_PCT
FROM (
		SELECT X.FKEntityId,
			   X.ApprPromos,
			   CASE WHEN X2.GMHires IS NULL THEN 0 ELSE X2.GMHires END AS GMHires,
			   CASE WHEN X2.RRHires IS NULL THEN 0 ELSE X2.RRHires END AS RRHires,
			   CASE WHEN X2.ApprHires IS NULL THEN 0 ELSE X2.ApprHires END AS ApprHires
		FROM
			(
			SELECT vfp.FKEntityId,
				   CAST(Count(vfp.EMPLID) as NUMERIC) as ApprPromos
			FROM   HR.[dbo].[vwFactPromotion] vfp
			INNER JOIN dbo.DimJobCode DJC
			ON vfp.Jobcode = DJC.JobCode
			AND djc.JobGroup = 'Appr'
			WHERE  vfp.Job_Entry_DT >= @StartDate
			GROUP BY vfp.FKEntityId
			) X
			LEFT OUTER JOIN 
			(
			SELECT vfh.EntityId,
				   CAST(Count(CASE WHEN DJC.JobGroup = 'GM' THEN vfh.employeeid END) as NUMERIC) AS GMHires, --- GM JOBCODES
				   CAST(Count(CASE WHEN DJC.JobGroup = 'R' THEN vfh.employeeid END) as NUMERIC) AS RRHires, --- RESTAURANTEUR JOBCODES
				   CAST(Count(CASE WHEN DJC.JobGroup = 'APPR' THEN vfh.employeeid END) as NUMERIC) AS ApprHires   --- APPRENTICE JOBCODES
			FROM   [HR].[dbo].[vwFactHiring] vfh
			INNER JOIN dbo.DimJobCode DJC
			ON vfh.Jobcode = DJC.JobCode
			AND DJC.JobGroup IN ('APPR','GM','R')  --- ALL GM/RESTAURANTEUR/APPRENTICE JOBCODES
			WHERE  vfh.HireDate >= @StartDate			        
			GROUP BY vfh.EntityId
            ) X2 ON X.FKEntityId = X2.entityid
)A
INNER JOIN dbo.dimCurrencyConversionDailyAverage ccda
ON A.FKEntityId = ccda.EntityID
AND ccda.Period = @Period
GROUP BY A.FKEntityId

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_Entity
ON #INT_HIRE_PCT (FKEntityID)


--- TEMP TABLE THAT COUNTS THE # OF EMPLOYEES AT A RESTAURANT THAT WERE TERM'ED IN 90 DAYS AND A COUNT OF TOTAL EMPLOYEES AT THE RESTAURANT

SELECT A.FKEntityID as FKEntityID,
		CASE WHEN B.NinetyDayTurnover IS NULL THEN 0 ELSE B.NinetyDayTurnover END as terms,
		A.currentempcnt  
INTO #NINETY_DAY_TURNOVER
FROM
(
SELECT pse.FKEntityID, 
		cast(count(pse.emplid) as numeric) CurrentEmpCnt
FROM HR.dbo.factEmployee pse
WHERE DT = @EndDate
		AND pse.EmplStatus = 'A'
GROUP BY pse.FKEntityID
) A
LEFT OUTER JOIN
(
SELECT vft.entityid,
		cast(count(psed.employeeid) as numeric) as NinetyDayTurnover
FROM  [Administrative].[dbo].[tblWWPeopleSoftExportDisabled] psed
INNER JOIN [HR].[dbo].[vwFactTurnover] vft
ON psed.employeeid = vft.employeeid
WHERE datediff(dd, psed.LastHireDate, vft.termDate) < 90
	AND datediff(dd, psed.LastHireDate, vft.termDate) > 0
	AND vft.TermDate >= @StartDate and vft.termDate <= @EndDate
GROUP BY vft.entityid
) B
ON A.FKEntityID = B.entityid
INNER JOIN dimCurrencyConversionDailyAverage CCDA
ON a.FKEntityID = CCDA.EntityID
AND ccda.Period = @Period

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_Entity
ON #NINETY_DAY_TURNOVER (FKEntityID)

---- TEMP TABLE THAT LISTS PROMOTION DATA FOR AN EMPLOYEE 
SELECT FED.EmployeeID,
        SUM(CASE WHEN fed.FKAccountID = 851 THEN AMOUNT ELSE 0 END) AS TDRestaurateurPromos, --- TD'S THAT PROMOTED A RESTAURATEUR
		SUM(CASE WHEN fed.FKAccountID = 852 THEN AMOUNT ELSE 0 END) AS FLRestaurateurPromos, --- FIELD LEADERS THAT PROMOTED A RESTAURATEUR
		SUM(CASE WHEN fed.FKAccountID = 853 THEN AMOUNT ELSE 0 END) AS TDATLPromos, --- TD'S THAT PROMOTED AN ATL
		SUM(CASE WHEN fed.FKAccountID = 854 THEN AMOUNT ELSE 0 END) AS FLATLPromos, --- FIELD LEADERS THAT PROMOTED AN ATL
		SUM(CASE WHEN fed.FKAccountID = 859 THEN AMOUNT ELSE 0 END) AS TDTLPromos --- TEAM DIRECTORS THAT PROMOTED A TL
INTO #FactEmployeeDataCTE
FROM dbo.factEmployeeData FED
WHERE FED.Period = @Period
AND FKAccountID IN (851,852,853,854,859) --- THESE ACCOUNTS ARE ATL/RT PROMOS FOR TD'S/FIELD LEADERS
GROUP BY FED.EmployeeID

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_EMPLID
ON #FactEmployeeDataCTE (EmployeeID)

------------------------------------------------------------
-- THE PURPOSE OF THIS TEMP TABLE IS TO BRING BACK THE RESTAURATEUR THEMES FOR THE MOST RECENT RESTAURATEUR VISIT FOR THE PREVIOUS TWO COMPLETED QUARTERS
-- FOR EXAMPLE, IF RUNNING THE FEBRUARY OPS SCORECARD....

		--•	You would bring restaurant visit dates for:
			--o	Q3 of PREVIOUS year
			--o	Q4 of PREVIOUS year
		--•	If a restaurant has more than one visit in a quarter, you bring back the MOST RECENT visit of that quarter

------------------------------------------------------------

select  vsi.StoreNumber, 
		rvv.id,
		rvv.submitdate,
		RVTa.themeid,
		RVT.tone,
		RVT.Title, 
		A.MaxQ1Date,
		A.MaxQ2Date
INTO #RVT
FROM   administrative.dbo.vwstoreinfo vsi
INNER JOIN dbo.[RestaurantVisitVisit] RVV
ON vsi.StoreNumber = RVV.RestaurantID
AND RVV.SubmitDate IS NOT NULL
INNER JOIN dbo.[RestaurantVisitThemeAnswer] RVTA
ON RVV.ID = RVTA.VisitID
INNER JOIN dbo.[RestaurantVisitTheme] RVT
ON RVTA.ThemeID = RVT.ID
INNER JOIN dbo.tblTime T
on CAST(RVV.SubmitDate as DATE) = T.Date
INNER JOIN 
		(
		SELECT RestaurantID,
			   MAX(CASE WHEN CAST(RVT.SubmitDate as Date) BETWEEN CAST(@Q1MinDate as Date) and CAST(@Q1MaxDate as Date) THEN SubmitDate END) as MaxQ1Date,
			   MAX(CASE WHEN CAST(RVT.SubmitDate as Date) BETWEEN CAST(@Q2MinDate as Date) and CAST(@Q2MaxDate as Date) THEN SubmitDate END) as MaxQ2Date
		FROM [RestaurantVisitVisit] RVT
		GROUP BY RestaurantID
		) A
ON vsi.StoreNumber = A.RestaurantID
GROUP BY vsi.StoreNumber, 
		rvv.id,
		rvv.submitdate,
		RVTa.themeid,
		RVT.tone,
		RVT.Title, 
		A.MaxQ1Date,
		A.MaxQ2Date

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_StoreNumber
ON #RVT (StoreNumber)


----- THIS TEMP TABLE CALCULATES THE TIME IN POSITION FOR A GIVEN EMPLOYEE
SELECT E.EMPLID, E.TimeInPOS
INTO #TimeInPOS
FROM
(
SELECT E.EMPLID, e.dt,
       Cast(Row_number() OVER ( partition BY E.emplid, E.jobcode ORDER BY dt) / 365.25 AS DEC(5, 2)) AS TimeInPOS
FROM   hr.dbo.factemployee E WITH (NOLOCK)
INNER JOIN dbo.dimJobCode djc
ON E.JOBCODE = djc.JobCode
AND (djc.AtModelJobCode = 'ATL/TL/AM'
	OR djc.AtModelJobCode = 'TD/ETD')
) E
INNER JOIN dbo.FactEmployeeOwnership FEO
ON E.EMPLID = FEO.EmployeeID
AND FEO.Period = @Period
WHERE e.dt = @EndDate
GROUP BY E.EMPLID, E.TimeInPOS

--- CREATE INDEX ON THE TABLE
CREATE INDEX idx_EMPLID
ON #TimeInPOS (EMPLID)


/*---- BEGIN THE INSERT INTO THE STAGING TABLE ----*/
INSERT INTO factEmployeeScorecard
SELECT feo.Period,             --- PERIOD THAT YOU'RE LOADING TO THE TABLE
       feo.EmployeeID,         --- EMPLOYEE THAT THE METRICS ARE TIED TO
	   CASE WHEN Position.Position IS NULL AND FEO.EMPLOYEEID = 124 THEN 'All Company' ELSE Position.Position END as Position,     --- CURRENT ROLE OF THE EMPLOYEE
       RestPct.EntityCnt,      --- HOW MANY ENTITIES ARE IN THEIR RESPECTIVE REGION/SUBREGION/PATCH
	   GreenStores.GreenCnt,   --- HOW MANY RESTAURANTS IN THE RESPECTIVE REGION/SUBREGION/PATCH THAT HAVE 0 NEGATIVE THEMES AT 5 POSITIVE THEMES
	   feo.EntityName,         --- LIST OF ENTITIES THAT THE EMPLOYEE IS OWNER OF
	   TimeInPOS.TimeInPOS,    --- HOW LONG EMPLOYEE HAS BEEN IN CURRENT ROLE
	   FED.TDRestaurateurPromos,  --- IF A TD, HOW MANY RT PROMOS THEY'VE HAD THAT MONTH
	   FED.FLRestaurateurPromos,  --- IF A FIELD LEADER, HOW MANY RT PROMOS THEY'VE HAD THAT MONTH
	   FED.TDTLPromos,    --- IF A TD, HOW MANY TL PROMOS THEY'VE HAD THAT MONTH
       FED.TDATLPromos,   --- IF A TD, HOW MANY ATL PROMOS THEY'VE HAD THAT MONTH
	   FED.FLATLPromos,   --- IF A FIELD LEADER, HOW MANY ATL PROMOS THEY'VE HAD THAT MONTH
	   CASE WHEN AtModel.EMPLID IS NOT NULL THEN AtModel.RestaurantsAtModel END as RestaurantsAtModel,  --- THE TOTAL NUMBER OF RESTAURANTS IN THEIR RESPECTIVE REGION/SUBREGION/PATCH THAT WERE AT MODEL
	   CASE WHEN AtModel.EMPLID IS NOT NULL THEN AtModel.Restaurants END as Restaurants, --- THE TOTAL NUMBER OF RESTAURANTS THAT THE FIELD LEADER HAS IN THEIR RESPECTIVE REGION/SUBREGION/PATCH 
	   CAST(CASE WHEN AtModel.EMPLID IS NOT NULL THEN AtModel.RestaurantsAtModel END AS NUMERIC)/CAST(CASE WHEN AtModel.EMPLID IS NOT NULL THEN AtModel.Restaurants END AS NUMERIC) as AtModelPercent,   --- TOTAL DAYS AT MODEL/TOTAL DAYS
	   OpsAudit.AvgMostRecentOpsAuditScore, --- AVERAGE SCORE OF MOST RECENT AUDIT IN THEIR RESPECTIVE REGION/SUBREGION/PATCH     
	   IntHirePct.YTDInternalHirePct,	    --- YTD PERCENTAGE OF GM'S THAT WERE INTERNALLY PROMOTED VS. EXTERNALLY HIRED
	   ProjvsActSales.ProjvsActSales,	    --- PROJECTED VS. ACTUAL SALES OF THEIR RESPECTIVE REGION/SUBREGION/PATCH FOR A MONTH
	   KMTermPct.KMTermPct,                 --- ANNUALIZED KM TERMINATIONS OF THEIR RESPECTIVE REGION/SUBREGION/PATCH
	   RecStaffingPct.RecStaffingPct,       --- YTD RECOMMENDED VS ACTUAL STAFFING OF THEIR RESPECTIVE REGION/SUBREGION/PATCH
	   NinetyDayTurnoverPct.NinetyDayTurnoverPct,   --- PCT OF EMPLOYEES THAT WERE TERMINATED W/IN 90 DAYS OF STARTING     
	   HundredPctAuditPct.HundredPctAuditPct,       --- PERCENTAGE OF ALL 4 PILLAR AUDITS THAT SCORED 100%  
	   FourPillarScore.FourPillarScore,   --- AVERAGE 4 PILLAR AUDIT SCORE FOR THEIR RESPECTIVE REGION/SUBREGION/PATCH 
	   AvgCashHandling.AvgCashHandling,   --- AVERAGE CASH HANDLING AUDIT SCORE FOR THEIR RESPECTIVE REGION/SUBREGION/PATCH
	   CDAuditPCT.CDAuditPCT,             --- TTM PERCENTAGE OF RESTUARANTS IN THEIR RESPECTIVE REGION/SUBREGION/PATCH THAT SCORED A C/D ON THEIR OPS AUDIT
	   FieldLeaderPct.FieldLeaderPct,     --- PERCENTAGE OF RESTAURANTS IN A REGION/SUBREGION THAT AREN'T DIRECTLY REPORTING TO A FIELD LEADER. THIS ISN'T EVALUATED FOR #Patches  
	   RestPct.RestPct,                   --- PERCENTAGE OF RESTAURANTS IN A REGION/SUBREGION/PATCH THAT ARE RESTAURATEUR RESTAURANTS
	   SUM(Q1NegComments)/RestPct.EntityCnt as Avg2PriorQtrsNegComments,  --- A TOTAL OF NEGATIVE COMMENTS FOR A REGION/SUBREGION/PATCH DIVIDED BY THE TOTAL NUMBER OF RESTAURANTS IN THE REGION/SUBREGION/PATCH COMPLETED QUARTER TWO QUARTERS IN ARREARS
	   SUM(Q2NegComments)/RestPct.EntityCnt as AvgPriorQtrNegComments --- A TOTAL OF NEGATIVE COMMENTS FOR A REGION/SUBREGION/PATCH DIVIDED BY THE TOTAL NUMBER OF RESTAURANTS IN THE REGION/SUBREGION/PATCH FOR THE PRIOR COMPLETED QUARTER
     FROM FactEmployeeOwnership FEO
LEFT OUTER JOIN #FactEmployeeDataCTE FED
ON FEO.EmployeeID = FED.EmployeeID
--- THIS LEFT OUTER JOIN UNIONS ALL THE AT MODEL DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (---- COMPANY LEVEL
				 SELECT  C.FKEmployeeID AS EMPLID,		 
					     sum(FKAccountID93) as RestaurantsAtModel,		
					     count(FKAccountID93) as Restaurants
				 FROM  #tblDailyMeasuresCalc dmd								 
						INNER JOIN dbo.tblEntityHierarchy eh
						ON dmd.FKEntityID = eh.FKEntityID
						INNER JOIN #Company C
						ON eh.FKEntityLevel1ID = C.FKEntityID
				 GROUP BY C.FKEmployeeID

				 UNION ALL
				 --- REGION LEVEL
				 SELECT R.FKRDID AS EMPLID,
						sum(FKAccountID93) as RestaurantsAtModel,		
						count(FKAccountID93) as Restaurants
				 FROM  #tblDailyMeasuresCalc dmd		
						INNER JOIN dbo.tblEntityHierarchy eh
						ON dmd.FKEntityID = eh.FKEntityID
						INNER JOIN #Regions R
						ON eh.FKEntityLevel3ID = R.FKEntityID
				 GROUP BY R.FKRDID
						
				 UNION ALL 
				 --- SUB REGION LEVEL	
				 SELECT  S.FKODID AS EMPLID,		 
						 sum(FKAccountID93) as RestaurantsAtModel,		
						 count(FKAccountID93) as Restaurants
				 FROM  #tblDailyMeasuresCalc dmd
						INNER JOIN dbo.tblEntityHierarchy eh
						ON dmd.FKEntityID = eh.FKEntityID
						INNER JOIN #SubRegions S
						ON eh.FKEntityLevel5ID = S.FKEntityID
				GROUP BY S.FKODID
						
				UNION ALL 
				---- PATCH LEVEL
				SELECT  p.FKEmployeeID AS EMPLID,		 
						sum(FKAccountID93) as RestaurantsAtModel,		
						count(FKAccountID93) as Restaurants
				 FROM  #tblDailyMeasuresCalc dmd								 
						INNER JOIN dbo.tblEntityHierarchy eh
						ON dmd.FKEntityID = eh.FKEntityID
						INNER JOIN #Patches P
						ON eh.FKEntityLevel7ID = P.FKEntityID
				GROUP BY p.FKEmployeeID
				)AtModel
ON FEO.EmployeeID = AtModel.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE MOST RECENT AUDIT SCORE DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (-- COMPANY LEVEL
                 SELECT C.FKEmployeeID EMPLID
						,CASE WHEN C.FKEmployeeID IS NOT NULL THEN  SUM(gld.FKAccountID828)  END /
						CASE WHEN C.FKEmployeeID IS NOT NULL THEN  COUNT(gld.FKAccountID828) END as AvgMostRecentOpsAuditScore
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh ON gld.FKEntityID = eh.FKEntityID
				LEFT OUTER JOIN #Company C
				ON eh.FKEntityLevel1ID = C.FKEntityID 
				GROUP BY C.FKEmployeeID

			    UNION ALL 
				-- REGION LEVEL
                SELECT R.FKRDID AS EMPLID
						,CASE WHEN R.FKRDID IS NOT NULL THEN  SUM(gld.FKAccountID828)  END /
						CASE WHEN R.FKRDID IS NOT NULL THEN  COUNT(gld.FKAccountID828) END as AvgMostRecentOpsAuditScore
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh ON gld.FKEntityID = eh.FKEntityID
				LEFT OUTER JOIN #Regions R ON eh.FKEntityLevel3ID = R.FKEntityID 
				GROUP BY r.FKRDID

				UNION ALL
				-- SUB-REGION LEVEL
				SELECT S.FKODID AS EMPLID   
						,CASE WHEN S.FKODID IS NOT NULL THEN  SUM(gld.FKAccountID828) END /
						CASE WHEN S.FKODID IS NOT NULL THEN  COUNT(gld.FKAccountID828) END as AvgMostRecentOpsAuditScore      
                                    
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh ON gld.FKEntityID = eh.FKEntityID
				LEFT OUTER JOIN #SubRegions S ON eh.FKEntityLevel5ID = S.FKEntityID
				GROUP BY S.FKODID

				UNION ALL
				-- PATCH LEVEL
				SELECT P.FKEmployeeID AS EMPLID
						,CASE WHEN P.FKEmployeeID IS NOT NULL THEN  SUM(gld.FKAccountID828) END /
						CASE WHEN P.FKEmployeeID IS NOT NULL THEN  COUNT(gld.FKAccountID828) END as AvgMostRecentOpsAuditScore                                    
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh ON gld.FKEntityID = eh.FKEntityID
				LEFT OUTER JOIN #Patches P ON eh.FKEntityLevel7ID = P.FKEntityID
				GROUP BY P.FKEmployeeID
				) OpsAudit
ON FEO.EmployeeID = OpsAudit.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE YTD INTERNAL HIRE PERCENTAGE DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (--- COMPANY LEVEL
                 SELECT C.FKEmployeeID AS EMPLID,
					    SUM(ihp.totalApprPromos)/SUM(ihp.totalHires) as YTDInternalHirePct
				FROM #INT_HIRE_PCT ihp
				INNER JOIN dbo.tblEntityHierarchy eh
				ON ihp.FKEntityID = eh.FKEntityID
				INNER JOIN #Company C
                ON eh.FKEntityLevel1ID = C.FKEntityID
				GROUP BY C.FKEmployeeID
				
				UNION ALL 

				--- REGION LEVEL
                SELECT R.FKRDID AS EMPLID,
					    SUM(ihp.totalApprPromos)/SUM(ihp.totalHires) as YTDInternalHirePct
				FROM #INT_HIRE_PCT ihp
				INNER JOIN dbo.tblEntityHierarchy eh
				ON ihp.FKEntityID = eh.FKEntityID
				INNER JOIN #Regions R
                ON eh.FKEntityLevel3ID = R.FKEntityID
				GROUP BY R.FKRDID

				UNION ALL
				--- SUB REGION LEVEL
                SELECT s.FKODID AS EMPLID,
					   SUM(ihp.totalApprPromos)/SUM(ihp.totalHires) as YTDInternalHirePct
				FROM #INT_HIRE_PCT ihp
				INNER JOIN dbo.tblEntityHierarchy eh
				ON ihp.FKEntityID = eh.FKEntityID
				INNER JOIN #SubRegions S
                ON eh.FKEntityLevel5ID = S.FKEntityID
				GROUP BY s.FKODID

				UNION ALL
				--- PATCH LEVEL
                SELECT p.FKEmployeeID AS EMPLID,
					   SUM(ihp.totalApprPromos)/SUM(ihp.totalHires) as YTDInternalHirePct
				FROM #INT_HIRE_PCT ihp
				INNER JOIN dbo.tblEntityHierarchy eh
				ON ihp.FKEntityID = eh.FKEntityID
				INNER JOIN #Patches P
                ON eh.FKEntityLevel7ID = P.FKEntityID
				GROUP BY p.FKEmployeeID
				) IntHirePct
ON FEO.EmployeeID = IntHirePct.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE PROJECTED VS ACTUAL SALES DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (--- COMPANY LEVEL
				 SELECT C.FKEmployeeID AS EMPLID,
					     SUM(PS.#ProjectedSales)/SUM(act.#ActualSales) as ProjvsActSales
				 FROM #ActualSales act
				 INNER JOIN #ProjectedSales PS
				 ON	 PS.FKEntityID = act.FKEntityID
				 INNER JOIN dbo.tblEntityHierarchy eh
				 ON act.FKEntityID = eh.FKEntityID
				 INNER JOIN #Company C
                 ON eh.FKEntityLevel1ID = C.FKEntityID
				 GROUP BY C.FKEmployeeID
          
		         UNION ALL 

				 --- REGION LEVEL
				 SELECT r.FKRDID AS EMPLID,
					     SUM(PS.#ProjectedSales)/SUM(act.#ActualSales) as ProjvsActSales
				 FROM #ActualSales act
				 INNER JOIN #ProjectedSales PS
				 ON	 PS.FKEntityID = act.FKEntityID
				 INNER JOIN dbo.tblEntityHierarchy eh
				 ON act.FKEntityID = eh.FKEntityID
				 INNER JOIN #Regions R
                 ON eh.FKEntityLevel3ID = R.FKEntityID
				 GROUP BY R.FKRDID

				 UNION ALL
				 --- SUBREGION LEVEL
                 SELECT S.FKODID AS EMPLID,
					    SUM(PS.#ProjectedSales)/SUM(act.#ActualSales) as ProjvsActSales
				 FROM #ActualSales act
				 INNER JOIN #ProjectedSales PS
				 ON	 PS.FKEntityID = act.FKEntityID
				 INNER JOIN dbo.tblEntityHierarchy eh
				 ON act.FKEntityID = eh.FKEntityID
				 INNER JOIN #SubRegions S
                 ON eh.FKEntityLevel5ID = S.FKEntityID
				 GROUP BY S.FKODID
                
				 UNION ALL
				 --- PATCH LEVEL
                 SELECT p.FKEmployeeID AS EMPLID,
					    SUM(PS.#ProjectedSales)/SUM(act.#ActualSales) as ProjvsActSales
				 FROM #ActualSales act
				 INNER JOIN #ProjectedSales PS
				 ON	 PS.FKEntityID = act.FKEntityID
				 INNER JOIN dbo.tblEntityHierarchy eh
				 ON act.FKEntityID = eh.FKEntityID
				 INNER JOIN #Patches P
                 ON eh.FKEntityLevel7ID = P.FKEntityID
				 GROUP BY p.FKEmployeeID
                 ) ProjvsActSales
ON FEO.EmployeeID = ProjvsActSales.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE ANNUALIZED KM TERMINATION PERCENTAGE DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (-- COMPANY LEVEL
                SELECT C.FKEmployeeID AS EMPLID,
						(SUM(KMTerminations.KMTerm)/RIGHT(@Period,2)*12)/SUM(KMTerminations.KMTotal) AS KMTermPct
				FROM
				(SELECT gld.FKEntityID,
						CASE WHEN SUM(FKAccountID834) IS NULL THEN 0 ELSE SUM(FKAccountID834) END as KMTerm,
						SUM(FKAccountID835) as KMTotal						
				FROM #tblGLDataCalc gld
				GROUP BY gld.FKEntityID
				) KMTerminations
				INNER JOIN dbo.tblEntityHierarchy eh
				ON KMTerminations.FKEntityID = eh.FKEntityID
				INNER JOIN #Company C
                ON eh.FKEntityLevel1ID = C.FKEntityID
				GROUP BY C.FKEmployeeID

				UNION ALL

				-- REGION LEVEL
                SELECT r.FKRDID AS EMPLID,
						(SUM(KMTerminations.KMTerm)/RIGHT(@Period,2)*12)/SUM(KMTerminations.KMTotal) AS KMTermPct
				FROM
				(SELECT gld.FKEntityID,
						CASE WHEN SUM(FKAccountID834) IS NULL THEN 0 ELSE SUM(FKAccountID834) END as KMTerm,
						SUM(FKAccountID835) as KMTotal						
				FROM #tblGLDataCalc gld
				GROUP BY gld.FKEntityID
				) KMTerminations
				INNER JOIN dbo.tblEntityHierarchy eh
				ON KMTerminations.FKEntityID = eh.FKEntityID
				INNER JOIN #Regions R
				ON eh.FKEntityLevel3ID = R.FKEntityID
				GROUP BY r.FKRDID

				 UNION ALL
				-- SUB-REGION LEVEL
				SELECT s.FKODID AS EMPLID,
						(SUM(KMTerminations.KMTerm)/RIGHT(@Period,2)*12)/SUM(KMTerminations.KMTotal) AS KMTermPct
				FROM
				(SELECT gld.FKEntityID,
						CASE WHEN SUM(FKAccountID834) IS NULL THEN 0 ELSE SUM(FKAccountID834) END as KMTerm,
						SUM(FKAccountID835) as KMTotal						
				FROM #tblGLDataCalc gld
				GROUP BY gld.FKEntityID
				) KMTerminations
				INNER JOIN dbo.tblEntityHierarchy eh
				ON KMTerminations.FKEntityID = eh.FKEntityID
				INNER JOIN #SubRegions S
				ON eh.FKEntityLevel5ID = S.FKEntityID
				GROUP BY s.FKODID

				UNION ALL 
				-- PATCH LEVEL
				SELECT P.FKEmployeeID AS EMPLID,
					   (SUM(KMTerminations.KMTerm)/RIGHT(@Period,2)*12)/SUM(KMTerminations.KMTotal) AS KMTermPct
				FROM
				(SELECT gld.FKEntityID,
						CASE WHEN SUM(FKAccountID834) IS NULL THEN 0 ELSE SUM(FKAccountID834) END as KMTerm,
						SUM(FKAccountID835) as KMTotal						
				FROM #tblGLDataCalc gld
				GROUP BY gld.FKEntityID
				) KMTerminations
				INNER JOIN dbo.tblEntityHierarchy eh
				ON KMTerminations.FKEntityID = eh.FKEntityID
				INNER JOIN #Patches P
				ON eh.FKEntityLevel7ID = P.FKEntityID
				GROUP BY P.FKEmployeeID
				) KMTermPct
ON FEO.EmployeeID = KMTermPct.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE RECOMMENDED STAFFING  PERCENTAGE DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (-- COMPANY LEVEL
                SELECT C.FKEmployeeID AS EMPLID,
					   SUM(FKAccountID848)/ SUM(FKAccountID847) as RecStaffingPct
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh
				ON gld.FKEntityID = eh.FKEntityID
				INNER JOIN #Company C
                ON eh.FKEntityLevel1ID = C.FKEntityID
				GROUP BY C.FKEmployeeID

				UNION ALL 
				-- REGION LEVEL
				SELECT r.FKRDID AS EMPLID,
					   SUM(FKAccountID848)/ SUM(FKAccountID847) as RecStaffingPct
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh
				ON gld.FKEntityID = eh.FKEntityID
				INNER JOIN #Regions R
				ON eh.FKEntityLevel3ID = R.FKEntityID
				GROUP BY r.FKRDID

				UNION ALL
				-- SUB-REGION LEVEL
				SELECT S.FKODID AS EMPLID,
					   SUM(FKAccountID848)/ SUM(FKAccountID847) as RecStaffingPct
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh
				ON gld.FKEntityID = eh.FKEntityID
				INNER JOIN #SubRegions S
				ON eh.FKEntityLevel5ID = S.FKEntityID
				GROUP BY S.FKODID

				UNION ALL 
				-- PATCH LEVEL
				SELECT P.FKEmployeeID AS EMPLID,
					   SUM(FKAccountID848)/ SUM(FKAccountID847) as RecStaffingPct
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh
				ON gld.FKEntityID = eh.FKEntityID
				INNER JOIN #Patches P
				ON eh.FKEntityLevel7ID = P.FKEntityID
				GROUP BY P.FKEmployeeID
				) RecStaffingPct
ON FEO.EmployeeID = RecStaffingPct.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE ANNUALIZED NINETY DAY TURNOVER PERCENTAGE DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN ( ---- COMPANY LEVEL
				 SELECT C.FKEmployeeID AS EMPLID,
                        (SUM(ndt.TERMS)/RIGHT(@Period,2)*12)/SUM(NDT.currentempcnt) as NinetyDayTurnoverPct
			     FROM #NINETY_DAY_TURNOVER NDT
				 INNER JOIN dbo.tblEntityHierarchy eh
				 ON NDT.FKEntityID = eh.FKEntityID
				 INNER JOIN #Company C
                 ON eh.FKEntityLevel1ID = C.FKEntityID
				 GROUP BY C.FKEmployeeID
				 
				 UNION ALL 
				 ---- REGION LEVEL
				 SELECT R.FKRDID AS EMPLID,
                        (SUM(ndt.TERMS)/RIGHT(@Period,2)*12)/SUM(NDT.currentempcnt) as NinetyDayTurnoverPct
			     FROM #NINETY_DAY_TURNOVER NDT
				 INNER JOIN dbo.tblEntityHierarchy eh
				 ON NDT.FKEntityID = eh.FKEntityID
				 INNER JOIN #Regions R
                 ON eh.FKEntityLevel3ID = R.FKEntityID
				 GROUP BY R.FKRDID
				 
				 UNION ALL 
				 --- SUBREGION LEVEL
				 SELECT s.FKODID AS EMPLID,
                        (SUM(ndt.TERMS)/RIGHT(@Period,2)*12)/SUM(NDT.currentempcnt) as NinetyDayTurnoverPct
			     FROM #NINETY_DAY_TURNOVER NDT
				 INNER JOIN dbo.tblEntityHierarchy eh
				 ON NDT.FKEntityID = eh.FKEntityID
				 INNER JOIN #SubRegions S
                 ON eh.FKEntityLevel5ID = S.FKEntityID
				 GROUP BY s.FKODID
				 
				 UNION ALL
				 --- PATCH LEVEL
				 SELECT p.FKEmployeeID AS EMPLID,
                        (SUM(ndt.TERMS)/RIGHT(@Period,2)*12)/SUM(NDT.currentempcnt) as NinetyDayTurnoverPct
			     FROM #NINETY_DAY_TURNOVER NDT
				 INNER JOIN dbo.tblEntityHierarchy eh
				 ON NDT.FKEntityID = eh.FKEntityID
				 INNER JOIN #Patches P
                 ON eh.FKEntityLevel7ID = P.FKEntityID
				 GROUP BY p.FKEmployeeID
				 ) NinetyDayTurnoverPct
ON FEO.EmployeeID = NinetyDayTurnoverPct.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE HUNDRED PERCENT AUDIT PERCENTAGE DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (-- COMPANY LEVEL
                SELECT C.FKEmployeeID AS EMPLID,
						SUM(OneHundredPctAudits)/SUM(CountofAudits) as HundredPctAuditPct
				FROM
					(SELECT gld.FKEntityID,
							CASE WHEN SUM(FKAccountID830) IS NOT NULL THEN SUM(FKAccountID830) ELSE 0 END AS OneHundredPctAudits,
							CASE WHEN SUM(FKAccountID829) IS NOT NULL THEN SUM(FKAccountID829) ELSE NULL END AS CountofAudits

					FROM #tblGLDataCalc gld
					GROUP BY gld.FKEntityID
					) FourPillars
					INNER JOIN dbo.tblEntityHierarchy eh
					ON FourPillars.FKEntityID = eh.FKEntityID
					INNER JOIN #Company C
                    ON eh.FKEntityLevel1ID = C.FKEntityID
				    GROUP BY C.FKEmployeeID

				UNION ALL 

				-- REGION LEVEL
                SELECT R.FKRDID AS EMPLID,
						SUM(OneHundredPctAudits)/SUM(CountofAudits) as HundredPctAuditPct
				FROM
					(SELECT gld.FKEntityID,
							CASE WHEN SUM(FKAccountID830) IS NOT NULL THEN SUM(FKAccountID830) ELSE 0 END AS OneHundredPctAudits,
							CASE WHEN SUM(FKAccountID829) IS NOT NULL THEN SUM(FKAccountID829) ELSE NULL END AS CountofAudits

					FROM #tblGLDataCalc gld
					GROUP BY gld.FKEntityID
					) FourPillars
					INNER JOIN dbo.tblEntityHierarchy eh
					ON FourPillars.FKEntityID = eh.FKEntityID
					INNER JOIN #Regions R
					ON eh.FKEntityLevel3ID = R.FKEntityID
					GROUP BY R.FKRDID

				UNION ALL 
								-- SUB-REGION LEVEL
				SELECT S.FKODID AS EMPLID,
						SUM(OneHundredPctAudits)/SUM(CountofAudits) as HundredPctAuditPct
				FROM
					(SELECT gld.FKEntityID,
							CASE WHEN SUM(FKAccountID830) IS NOT NULL THEN SUM(FKAccountID830) ELSE 0 END AS OneHundredPctAudits,
							CASE WHEN SUM(FKAccountID829) IS NOT NULL THEN SUM(FKAccountID829) ELSE NULL END AS CountofAudits

					FROM #tblGLDataCalc gld
					GROUP BY gld.FKEntityID
					) FourPillars
					INNER JOIN dbo.tblEntityHierarchy eh
					ON FourPillars.FKEntityID = eh.FKEntityID
					INNER JOIN #SubRegions S
					ON eh.FKEntityLevel5ID = S.FKEntityID
					GROUP BY S.FKODID

				UNION ALL 
				-- PATCH LEVEL
				SELECT P.FKEmployeeID AS EMPLID,
						SUM(OneHundredPctAudits)/SUM(CountofAudits) as HundredPctAuditPct
				FROM
					(SELECT gld.FKEntityID,
							CASE WHEN SUM(FKAccountID830) IS NOT NULL THEN SUM(FKAccountID830) ELSE 0 END AS OneHundredPctAudits,
							CASE WHEN SUM(FKAccountID829) IS NOT NULL THEN SUM(FKAccountID829) ELSE NULL END AS CountofAudits

					FROM #tblGLDataCalc gld
					GROUP BY gld.FKEntityID
					) FourPillars
					INNER JOIN dbo.tblEntityHierarchy eh
					ON FourPillars.FKEntityID = eh.FKEntityID
					INNER JOIN #Patches P
					ON eh.FKEntityLevel7ID = P.FKEntityID
					GROUP BY P.FKEmployeeID
				) HundredPctAuditPct
ON FEO.EmployeeID = HundredPctAuditPct.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE AVERAGE 4 PILLAR AUDIT DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (-- REGION LEVEL
                SELECT C.FKEmployeeID AS EMPLID,
						SUM(ActualScore)/SUM(PossibleScore) as FourPillarScore
				FROM
					(SELECT gld.FKEntityID,
							CASE WHEN SUM(FKAccountID840) IS NOT NULL THEN SUM(FKAccountID840) ELSE 0 END AS ActualScore,
							CASE WHEN SUM(FKAccountID839) IS NOT NULL THEN SUM(FKAccountID839) ELSE NULL END AS PossibleScore

					FROM #tblGLDataCalc gld
					GROUP BY gld.FKEntityID
					) AvgFourPillarsAchieved
					INNER JOIN dbo.tblEntityHierarchy eh
					ON AvgFourPillarsAchieved.FKEntityID = eh.FKEntityID
					INNER JOIN #Company C
                    ON eh.FKEntityLevel1ID = C.FKEntityID
				    GROUP BY C.FKEmployeeID

				UNION ALL 
				-- REGION LEVEL
                SELECT R.FKRDID AS EMPLID,
						SUM(ActualScore)/SUM(PossibleScore) as FourPillarScore
				FROM
					(SELECT gld.FKEntityID,
							CASE WHEN SUM(FKAccountID840) IS NOT NULL THEN SUM(FKAccountID840) ELSE 0 END AS ActualScore,
							CASE WHEN SUM(FKAccountID839) IS NOT NULL THEN SUM(FKAccountID839) ELSE NULL END AS PossibleScore

					FROM #tblGLDataCalc gld
					GROUP BY gld.FKEntityID
					) AvgFourPillarsAchieved
					INNER JOIN dbo.tblEntityHierarchy eh
					ON AvgFourPillarsAchieved.FKEntityID = eh.FKEntityID
					INNER JOIN #Regions R
					ON eh.FKEntityLevel3ID = R.FKEntityID
					GROUP BY R.FKRDID

				UNION ALL 
				-- SUB-REGION LEVEL
				SELECT S.FKODID AS EMPLID,
						SUM(ActualScore)/SUM(PossibleScore) as FourPillarScore
				FROM
					(SELECT gld.FKEntityID,
							CASE WHEN SUM(FKAccountID840) IS NOT NULL THEN SUM(FKAccountID840) ELSE 0 END AS ActualScore,
							CASE WHEN SUM(FKAccountID839) IS NOT NULL THEN SUM(FKAccountID839) ELSE NULL END AS PossibleScore

					FROM #tblGLDataCalc gld
					GROUP BY gld.FKEntityID
					) AvgFourPillarsAchieved
					INNER JOIN dbo.tblEntityHierarchy eh
					ON AvgFourPillarsAchieved.FKEntityID = eh.FKEntityID
					INNER JOIN #SubRegions S
					ON eh.FKEntityLevel5ID = S.FKEntityID
					GROUP BY S.FKODID

				UNION ALL
				-- PATCH LEVEL
				SELECT P.FKEmployeeID AS EMPLID,
						SUM(ActualScore)/SUM(PossibleScore) as FourPillarScore
				FROM
					(SELECT gld.FKEntityID,
							CASE WHEN SUM(FKAccountID840) IS NOT NULL THEN SUM(FKAccountID840) ELSE 0 END AS ActualScore,
							CASE WHEN SUM(FKAccountID839) IS NOT NULL THEN SUM(FKAccountID839) ELSE NULL END AS PossibleScore

					FROM #tblGLDataCalc gld
					GROUP BY gld.FKEntityID
					) AvgFourPillarsAchieved
					INNER JOIN dbo.tblEntityHierarchy eh
					ON AvgFourPillarsAchieved.FKEntityID = eh.FKEntityID
					INNER JOIN #Patches P
					ON eh.FKEntityLevel7ID = P.FKEntityID
					GROUP BY P.FKEmployeeID
				) FourPillarScore
ON FEO.EmployeeID = FourPillarScore.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE AVERAGE CASH HANDLING SCORE DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (-- COMPANY LEVEL
                SELECT C.FKEmployeeID AS EMPLID,
						SUM(RegionCashHandling.SumScores)/SUM(RegionCashHandling.CountAudits) AS AvgCashHandling
				FROM
					(SELECT eh.FKEntityID,
						CASE WHEN SUM(FKAccountID842) IS NULL THEN 0 ELSE SUM(FKAccountID842) END AS SumScores ,
						CASE WHEN SUM(FKAccountID843) IS NULL THEN 0 ELSE SUM(FKAccountID843) END CountAudits
					FROM #tblGLDataCalc gld
					JOIN dbo.tblEntityHierarchy eh
					ON gld.FKEntityID = eh.FKEntityID
					GROUP BY eh.FKEntityID
					) RegionCashHandling
					INNER JOIN dbo.tblEntityHierarchy eh
					ON RegionCashHandling.FKEntityID = eh.FKEntityID
					INNER JOIN #Company C
                    ON eh.FKEntityLevel1ID = C.FKEntityID
				    GROUP BY C.FKEmployeeID

				UNION ALL
				-- REGION LEVEL
                SELECT R.FKRDID AS EMPLID,
						SUM(RegionCashHandling.SumScores)/SUM(RegionCashHandling.CountAudits) AS AvgCashHandling
				FROM
					(SELECT eh.FKEntityID,
						CASE WHEN SUM(FKAccountID842) IS NULL THEN 0 ELSE SUM(FKAccountID842) END AS SumScores ,
						CASE WHEN SUM(FKAccountID843) IS NULL THEN 0 ELSE SUM(FKAccountID843) END CountAudits
					FROM #tblGLDataCalc gld
					JOIN dbo.tblEntityHierarchy eh
					ON gld.FKEntityID = eh.FKEntityID
					GROUP BY eh.FKEntityID
					) RegionCashHandling
					INNER JOIN dbo.tblEntityHierarchy eh
					ON RegionCashHandling.FKEntityID = eh.FKEntityID
					INNER JOIN #Regions R
					ON eh.FKEntityLevel3ID = R.FKEntityID
					GROUP BY r.FKRDID

				UNION ALL
				-- SUB-REGION LEVEL
				SELECT S.FKODID AS EMPLID,
						SUM(RegionCashHandling.SumScores)/SUM(RegionCashHandling.CountAudits) AS AvgCashHandling
				FROM
					(SELECT eh.FKEntityID,
						CASE WHEN SUM(FKAccountID842) IS NULL THEN 0 ELSE SUM(FKAccountID842) END AS SumScores ,
						CASE WHEN SUM(FKAccountID843) IS NULL THEN NULL ELSE SUM(FKAccountID843) END CountAudits
					FROM #tblGLDataCalc gld
					JOIN dbo.tblEntityHierarchy eh
					ON gld.FKEntityID = eh.FKEntityID
					GROUP BY eh.FKEntityID
					) RegionCashHandling
					INNER JOIN dbo.tblEntityHierarchy eh
					ON RegionCashHandling.FKEntityID = eh.FKEntityID
					INNER JOIN #SubRegions S
					ON eh.FKEntityLevel5ID = S.FKEntityID
					GROUP BY S.FKODID

				UNION ALL 
				-- PATCH LEVEL
				SELECT P.FKEmployeeID AS EMPLID,
						SUM(RegionCashHandling.SumScores)/SUM(RegionCashHandling.CountAudits) AS AvgCashHandling
				FROM
					(SELECT eh.FKEntityID,
						CASE WHEN SUM(FKAccountID842) IS NULL THEN 0 ELSE SUM(FKAccountID842) END AS SumScores ,
						CASE WHEN SUM(FKAccountID843) IS NULL THEN NULL ELSE SUM(FKAccountID843) END CountAudits
					FROM #tblGLDataCalc gld
					JOIN dbo.tblEntityHierarchy eh
					ON gld.FKEntityID = eh.FKEntityID
					GROUP BY eh.FKEntityID
					) RegionCashHandling
					INNER JOIN dbo.tblEntityHierarchy eh
					ON RegionCashHandling.FKEntityID = eh.FKEntityID
					INNER JOIN #Patches P
					ON eh.FKEntityLevel7ID = P.FKEntityID
					GROUP BY P.FKEmployeeID
				) AvgCashHandling
ON FEO.EmployeeID = AvgCashHandling.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE TTM PERCENTAGE OF C&D AUDITS DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN	(-- COMPANY LEVEL
					SELECT C.FKEmployeeID AS EMPLID,
						   SUM(RegionCDAudit.CDCount)/SUM(RegionCDAudit.CountAudits) AS CDAuditPCT
					FROM
					(SELECT eh.FKEntityID,
							CASE WHEN SUM(FKAccountID841) IS NULL THEN 0 ELSE SUM(FKAccountID841) END AS CDCount,
							CASE WHEN SUM(FKAccountID844) IS NULL THEN NULL ELSE SUM(FKAccountID844) END CountAudits
						FROM #tblGLDataCalc gld
						JOIN dbo.tblEntityHierarchy eh
						ON gld.FKEntityID = eh.FKEntityID
						GROUP BY eh.FKEntityID
					) RegionCDAudit
					INNER JOIN dbo.tblEntityHierarchy eh
					ON RegionCDAudit.FKEntityID = eh.FKEntityID
					INNER JOIN #Company C
                    ON eh.FKEntityLevel1ID = C.FKEntityID
				    GROUP BY C.FKEmployeeID

					UNION ALL
					-- REGION LEVEL
					SELECT R.FKRDID AS EMPLID,
						   SUM(RegionCDAudit.CDCount)/SUM(RegionCDAudit.CountAudits) AS CDAuditPCT
					FROM
					(SELECT eh.FKEntityID,
							CASE WHEN SUM(FKAccountID841) IS NULL THEN 0 ELSE SUM(FKAccountID841) END AS CDCount,
							CASE WHEN SUM(FKAccountID844) IS NULL THEN NULL ELSE SUM(FKAccountID844) END CountAudits
						FROM #tblGLDataCalc gld
						JOIN dbo.tblEntityHierarchy eh
						ON gld.FKEntityID = eh.FKEntityID
						GROUP BY eh.FKEntityID
					) RegionCDAudit
					INNER JOIN dbo.tblEntityHierarchy eh
					ON RegionCDAudit.FKEntityID = eh.FKEntityID
					INNER JOIN #Regions R
					ON eh.FKEntityLevel3ID = R.FKEntityID
					GROUP BY r.FKRDID

					UNION ALL  
					-- SUB-REGION LEVEL
					SELECT S.FKODID AS EMPLID,
							SUM(RegionCDAudit.CDCount)/SUM(RegionCDAudit.CountAudits) AS CDAuditPCT
					FROM
					(SELECT eh.FKEntityID,
							CASE WHEN SUM(FKAccountID841) IS NULL THEN 0 ELSE SUM(FKAccountID841) END AS CDCount,
							CASE WHEN SUM(FKAccountID844) IS NULL THEN NULL ELSE SUM(FKAccountID844) END CountAudits
						FROM #tblGLDataCalc gld
						JOIN dbo.tblEntityHierarchy eh
						ON gld.FKEntityID = eh.FKEntityID
						GROUP BY eh.FKEntityID
					) RegionCDAudit
					INNER JOIN dbo.tblEntityHierarchy eh
					ON RegionCDAudit.FKEntityID = eh.FKEntityID
					INNER JOIN #SubRegions S
					ON eh.FKEntityLevel5ID = S.FKEntityID
					GROUP BY S.FKODID

					UNION ALL 
					-- PATCH LEVEL
					SELECT P.FKEmployeeID AS EMPLID,
							SUM(RegionCDAudit.CDCount)/SUM(RegionCDAudit.CountAudits) AS CDAuditPCT
					FROM
					(SELECT eh.FKEntityID,
							CASE WHEN SUM(FKAccountID841) IS NULL THEN 0 ELSE SUM(FKAccountID841) END AS CDCount,
							CASE WHEN SUM(FKAccountID844) IS NULL THEN NULL ELSE SUM(FKAccountID844) END CountAudits
						FROM #tblGLDataCalc gld
						JOIN dbo.tblEntityHierarchy eh
						ON gld.FKEntityID = eh.FKEntityID
						GROUP BY eh.FKEntityID
						) RegionCDAudit
					INNER JOIN dbo.tblEntityHierarchy eh
					ON RegionCDAudit.FKEntityID = eh.FKEntityID
					INNER JOIN #Patches P
					ON eh.FKEntityLevel7ID = P.FKEntityID
					GROUP BY P.FKEmployeeID
				    ) CDAuditPCT
ON FEO.EmployeeID = CDAuditPCT.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE PERCENTAGE OF RESTAURANTS NOT REPORTING DIRECTLY TO A FIELD LEADER  DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (-- COMPANY LEVEL
                SELECT C.FKEmployeeID AS EMPLID,
						CAST(SUM(FKAccountID846) AS NUMERIC)/
						CAST(COUNT(FKAccountID846) AS NUMERIC) as FieldLeaderPct
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh
				ON gld.FKEntityID = eh.FKEntityID
				INNER JOIN dbo.tblStores S
				ON EH.FKEntityID = S.FKEntityID
				AND s.OpenDate <= @EndDate
			    AND (s.CloseDate IS NULL 
			    OR s.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
				INNER JOIN #Company C
                ON eh.FKEntityLevel1ID = C.FKEntityID
				GROUP BY C.FKEmployeeID

				UNION ALL

				-- REGION LEVEL
                SELECT R.FKRDID AS EMPLID,
						CAST(SUM(FKAccountID846) AS NUMERIC)/
						CAST(COUNT(FKAccountID846) AS NUMERIC) as FieldLeaderPct
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh
				ON gld.FKEntityID = eh.FKEntityID
				INNER JOIN dbo.tblStores S
				ON EH.FKEntityID = S.FKEntityID
				AND s.OpenDate <= @EndDate
			    AND (s.CloseDate IS NULL 
			    OR s.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
				INNER JOIN #Regions R
				ON eh.FKEntityLevel3ID = R.FKEntityID
				GROUP BY R.FKRDID

				UNION ALL
				-- SUB-REGION LEVEL
				SELECT S.FKODID AS EMPLID,
						CAST(SUM(FKAccountID846) AS NUMERIC)/
						CAST(COUNT(FKAccountID846) AS NUMERIC) as FieldLeaderPct
				FROM #tblGLDataCalc gld
				INNER JOIN dbo.tblEntityHierarchy eh
				ON gld.FKEntityID = eh.FKEntityID
				INNER JOIN dbo.tblStores S2
				ON EH.FKEntityID = S2.FKEntityID
				AND s2.OpenDate <= @EndDate
			    AND (s2.CloseDate IS NULL 
			    OR s2.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
				INNER JOIN #SubRegions S
				ON eh.FKEntityLevel5ID = S.FKEntityID
				GROUP BY S.FKODID
				
		--- WE DONT EVALUATE ATL/TL/AM FOR THIS METRIC

				) FieldLeaderPct
ON FEO.EmployeeID = FieldLeaderPct.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE PERCENTEAGE OF RESTAURANTS IN THE PATCH/SUBREGION/REGION THAT ARE RESTAURATEUR DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (--- COMPANY LEVEL
                 SELECT A.FKEmployeeID AS EMPLID,
						A.EntityCnt,
					    B.RRest/A.EntityCnt as RestPct
				 FROM
					(
					SELECT C.FKEmployeeID,
						   CAST(COUNT(distinct eh.FKEntityID) as Numeric) as EntityCnt
					FROM #Company C
					INNER JOIN dbo.tblEntityHierarchy EH
					ON C.FKEntityID = eh.FKEntityLevel1ID
					INNER JOIN dbo.tblStores S
					ON EH.FKEntityID = S.FKEntityID
					AND s.OpenDate <= @EndDate
			        AND (s.CloseDate IS NULL 
			        OR s.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
					GROUP BY C.FKEmployeeID
					) A
					LEFT OUTER JOIN 
					(
					SELECT  C.FKEmployeeID,
							CAST(CASE WHEN COUNT(distinct RSP.R1RestNum) IS NULL THEN 0 ELSE COUNT(distinct RSP.R1RestNum) END as NUMERIC) as RRest
					FROM #Company C
					INNER JOIN dbo.tblEntityHierarchy EH
					ON C.FKEntityID = eh.FKEntityLevel1ID
					INNER JOIN dbo.tblStores S
					ON eh.FKEntityID = s.FKEntityID
					AND s.OpenDate <= @EndDate
			        AND (s.CloseDate IS NULL 
			        OR s.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
					INNER JOIN [Administrative].[dbo].[tblRestaurateursSharePoint] RSP
					ON S.PKStoreID = RSP.R1RestNum
					GROUP BY C.FKEmployeeID
					) B
					ON A.FKEmployeeID = B.FKEmployeeID
				
				 UNION ALL 
				 --- REGION LEVEL
                 SELECT A.FKRDID AS EMPLID,
						A.EntityCnt,
					    B.RRest/A.EntityCnt as RestPct
				 FROM
					(
					SELECT R.FKRDID,
						   CAST(COUNT(distinct eh.FKEntityID) as Numeric) as EntityCnt
					FROM #Regions R
					INNER JOIN dbo.tblEntityHierarchy EH
					ON R.FKEntityID = eh.FKEntityLevel3ID
					INNER JOIN dbo.tblStores S
					ON eh.FKEntityID = s.FKEntityID
					AND s.OpenDate <= @EndDate
			        AND (s.CloseDate IS NULL 
			        OR s.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
					GROUP BY R.FKRDID
					) A
					LEFT OUTER JOIN 
					(
					SELECT  R.FKRDID,
							CAST(CASE WHEN COUNT(distinct RSP.R1RestNum) IS NULL THEN 0 ELSE COUNT(distinct RSP.R1RestNum) END as NUMERIC) as RRest
					FROM #Regions R
					INNER JOIN dbo.tblEntityHierarchy eh
					ON R.FKEntityID = eh.FKEntityLevel3ID
					INNER JOIN dbo.tblStores S
					ON eh.FKEntityID = s.FKEntityID
					AND s.OpenDate <= @EndDate
			        AND (s.CloseDate IS NULL 
			        OR s.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
					INNER JOIN [Administrative].[dbo].[tblRestaurateursSharePoint] RSP
					ON S.PKStoreID = RSP.R1RestNum
					GROUP BY R.FKRDID
					) B
					ON A.FKRDID = B.FKRDID
				
				 UNION ALL 
				 --- SUBREGION LEVEL
				 SELECT A.FKODID AS EMPLID,
						A.EntityCnt,
					    B.RRest/A.EntityCnt AS RestPct   
				 FROM
					(
					SELECT S.FKODID,
						   CAST(COUNT(distinct eh.FKEntityID) as Numeric) as EntityCnt
					FROM #SubRegions S
					INNER JOIN dbo.tblEntityHierarchy EH
					ON S.FKEntityID = eh.FKEntityLevel5ID
					INNER JOIN dbo.tblStores S2
					ON eh.FKEntityID = s2.FKEntityID
					AND s2.OpenDate <= @EndDate
			        AND (s2.CloseDate IS NULL 
			        OR s2.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
					GROUP BY S.FKODID
					) A
					LEFT OUTER JOIN 
					(
					SELECT  S.FKODID,
							CAST(CASE WHEN COUNT(distinct RSP.R1RestNum) IS NULL THEN 0 ELSE COUNT(distinct RSP.R1RestNum) END as NUMERIC) as RRest
					FROM #SubRegions S
					INNER JOIN dbo.tblEntityHierarchy eh
					ON S.FKEntityID = eh.FKEntityLevel5ID
					INNER JOIN dbo.tblStores S2
					ON eh.FKEntityID = S2.FKEntityID
					AND s2.OpenDate <= @EndDate
			        AND (s2.CloseDate IS NULL 
			        OR s2.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
					INNER JOIN [Administrative].[dbo].[tblRestaurateursSharePoint] RSP
					ON S2.PKStoreID = RSP.R1RestNum
					GROUP BY S.FKODID
					) B
					ON A.FKODID = B.FKODID
				
				 UNION ALL 
				 --- PATCH LEVEL
				 SELECT A.FKEmployeeID AS EMPLID,
                        A.EntityCnt,
					    B.RRest/A.EntityCnt AS RestPct  
				 FROM
					(
					SELECT p.FKEmployeeID, 
							CAST(COUNT(distinct eh.FKEntityID) as Numeric) as EntityCnt
					FROM #Patches P
					INNER JOIN dbo.tblEntityHierarchy EH
					ON p.FKEntityID = eh.FKEntityLevel7ID
					INNER JOIN dbo.tblStores S
					ON eh.FKEntityID = s.FKEntityID
					AND s.OpenDate <= @EndDate
			        AND (s.CloseDate IS NULL 
			        OR s.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
					AND EH.EntityLevel7 NOT LIKE '%New Store%' -- DONT COUNT NEW STORES
					GROUP BY p.FKEmployeeID
					) A
					LEFT OUTER JOIN 
					(
					SELECT p.FKEmployeeID,
							CAST(CASE WHEN COUNT(distinct RSP.R1RestNum) IS NULL THEN 0 ELSE COUNT(distinct RSP.R1RestNum) END as NUMERIC) as RRest
					FROM #Patches P
					INNER JOIN dbo.tblEntityHierarchy eh
					ON P.FKEntityID = eh.FKEntityLevel7ID
					AND EH.EntityLevel7 NOT LIKE '%New Store%' --- DONT COUNT NEW STORES
					INNER JOIN dbo.tblStores S
					ON eh.FKEntityID = s.FKEntityID
					AND s.OpenDate <= @EndDate
			        AND (s.CloseDate IS NULL 
			        OR s.CloseDate BETWEEN @StartDatePeriod AND @EndDate) 
					INNER JOIN [Administrative].[dbo].[tblRestaurateursSharePoint] RSP
					ON S.PKStoreID = RSP.R1RestNum
					GROUP BY p.FKEmployeeID
					) B
					ON A.FKEmployeeID = B.FKEmployeeID
				) RestPct
ON FEO.EmployeeID = RestPct.EMPLID
--- THIS LEFT OUTER JOIN CALCULATES ALL THE POSITION AND TIME IN POSITION DATA FOR Regions/SubRegions/Patches
LEFT OUTER JOIN	( 
				SELECT TIP.EMPLID,						
					   TIP.TimeInPOS 
				FROM   HR.DBO.FactEmployee E
				       INNER JOIN #TimeInPOS TIP
					   ON E.EMPLID = TIP.EMPLID
					   INNER JOIN (SELECT EMPLID, MAX(DT) AS MAXDATE
								   FROM HR.DBO.factemployee 
									GROUP BY EMPLID
									) MAXDATE
						ON TIP.EMPLID = MAXDATE.EMPLID						
						AND E.DT = MAXDATE.MAXDATE						
				GROUP BY TIP.EMPLID,
						 TIP.TimeInPOS
				) TimeInPOS
ON FEO.EmployeeID = TimeInPOS.EMPLID
LEFT OUTER JOIN (
				SELECT E.EMPLID,
						djc.Description as Position --- 124 IS STEVE'S EMPLOYEEID AND WE USE THAT TO REPORT ON ALL COMPANY
				FROM   hr.dbo.factemployee e
						INNER JOIN dbo.dimJobCode djc
						ON e.JOBCODE = djc.JobCode
						AND (djc.AtModelJobCode = 'ATL/TL/AM'
							OR djc.AtModelJobCode = 'TD/ETD')
						INNER JOIN (SELECT EMPLID, MAX(effdt) AS PROMODATE
									FROM HR.DBO.PS_JOB PSJ
									WHERE ACTION IN ('PRO', 'HIR', 'REH')
									GROUP BY EMPLID
									) PROMO
						ON e.EMPLID = PROMO.EMPLID	
						AND PROMO.PROMODATE = E.DT					
				GROUP BY E.emplid,
						djc.Description
                ) Position
ON FEO.EmployeeID = Position.EMPLID        
--- THIS LEFT OUTER JOIN UNIONS ALL THE COUNT OF "GREEN STORES" DATA FOR #Regions/#SubRegions/#Patches
LEFT OUTER JOIN (--- COMPANY LEVEL
                SELECT C.FKEmployeeID as EMPLID,
					   COUNT(distinct GreenStores.FKEntityID) as GreenCnt
				FROM
				(SELECT  S.FKEntityID,    /* THIS SUB QUERY REFERENCES THE CTE TO BRING BACK THE AMOUNT NEGATIVE COMMENTS AT EACH RESTAURANT VISIT IN A QUARTER*/
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS NegComments, -- COMMENTS WITH A TONE OF '2' ARE NEGATIVE 
						SUM(CASE WHEN #RVT.TONE = 1 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS PosComments -- COMMENTS WITH A TONE OF '1' ARE POSITIVE
						FROM #RVT
				INNER JOIN dbo.tblStores S
				ON #RVT.StoreNUmber = S.PKStoreID
				GROUP BY S.FKEntityID
				) GreenStores
				INNER JOIN dbo.tblEntityHierarchy EH
				ON GreenStores.FKEntityID = EH.FKEntityID
				INNER JOIN #Company C
                ON eh.FKEntityLevel1ID = C.FKEntityID				
				WHERE GreenStores.NegComments = 0 -- A GREEN RESTAURANT HAS 0 NEGATIVE COMMENTS AND 5 POSITIVE COMMENTS
					AND GreenStores.PosComments = 5
				GROUP BY C.FKEmployeeID

				UNION ALL
				--- REGION LEVEL
                SELECT R.FKRDID as EMPLID,
					   COUNT(distinct GreenStores.FKEntityID) as GreenCnt
				FROM
				(SELECT  S.FKEntityID,    /* THIS SUB QUERY REFERENCES THE CTE TO BRING BACK THE AMOUNT NEGATIVE COMMENTS AT EACH RESTAURANT VISIT IN A QUARTER*/
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS NegComments, -- COMMENTS WITH A TONE OF '2' ARE NEGATIVE 
						SUM(CASE WHEN #RVT.TONE = 1 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS PosComments -- COMMENTS WITH A TONE OF '1' ARE POSITIVE
						FROM #RVT
				INNER JOIN dbo.tblStores S
				ON #RVT.StoreNUmber = S.PKStoreID
				GROUP BY S.FKEntityID
				) GreenStores
				INNER JOIN dbo.tblEntityHierarchy EH
				ON GreenStores.FKEntityID = EH.FKEntityID
				INNER JOIN #Regions R
				ON EH.FKEntityLevel3ID = R.FKEntityID
				WHERE GreenStores.NegComments = 0 -- A GREEN RESTAURANT HAS 0 NEGATIVE COMMENTS AND 5 POSITIVE COMMENTS
					AND GreenStores.PosComments = 5
				GROUP BY R.FKRDID

				UNION ALL
				--- SUB REGION LEVEL
				SELECT S.FKODID as EMPLID,
					   COUNT(distinct GreenStores.FKEntityID) as GreenCnt
				FROM
				(SELECT  S.FKEntityID,     /* THIS SUB QUERY REFERENCES THE CTE TO BRING BACK THE AMOUNT NEGATIVE COMMENTS AT EACH RESTAURANT VISIT IN A QUARTER*/
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS NegComments,  -- COMMENTS WITH A TONE OF '2' ARE NEGATIVE
						SUM(CASE WHEN #RVT.TONE = 1 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS PosComments  -- COMMENTS WITH A TONE OF '1' ARE POSITIVE
						FROM #RVT
				INNER JOIN dbo.tblStores S
				ON #RVT.StoreNUmber = S.PKStoreID
				GROUP BY S.FKEntityID
				) GreenStores
				INNER JOIN dbo.tblEntityHierarchy EH
				ON GreenStores.FKEntityID = EH.FKEntityID
				INNER JOIN #SubRegions S
				ON EH.FKEntityLevel5ID = S.FKEntityID
				WHERE GreenStores.NegComments = 0 -- A GREEN RESTAURANT HAS 0 NEGATIVE COMMENTS AND 5 POSITIVE COMMENTS
					AND GreenStores.PosComments = 5
				GROUP BY S.FKODID

				UNION ALL
				--- PATCH LEVEL
				SELECT P.FKEmployeeID as EMPLID,
					   COUNT(distinct GreenStores.FKEntityID) as GreenCnt
				FROM
				(SELECT  S.FKEntityID,     /* THIS SUB QUERY REFERENCES THE CTE TO BRING BACK THE AMOUNT NEGATIVE COMMENTS AT EACH RESTAURANT VISIT IN A QUARTER*/
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS NegComments, -- COMMENTS WITH A TONE OF '2' ARE NEGATIVE
						SUM(CASE WHEN #RVT.TONE = 1 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS PosComments -- COMMENTS WITH A TONE OF '1' ARE POSITIVE
						FROM #RVT
				INNER JOIN dbo.tblStores S
				ON #RVT.StoreNUmber = S.PKStoreID
				GROUP BY S.FKEntityID
				) GreenStores
				INNER JOIN dbo.tblEntityHierarchy EH
				ON GreenStores.FKEntityID = EH.FKEntityID
				INNER JOIN #Patches P
				ON EH.FKEntityLevel7ID = P.FKEntityID
				WHERE GreenStores.NegComments = 0 -- A GREEN RESTAURANT HAS 0 NEGATIVE COMMENTS AND 5 POSITIVE COMMENTS
					AND GreenStores.PosComments = 5
				GROUP BY P.FKEmployeeID
				) GreenStores
ON FEO.EmployeeID = GreenStores.EMPLID
--- THIS LEFT OUTER JOIN UNIONS ALL THE AVERAGE NEGATIVE COMMENTS IN A QUARTER DATA FOR Regions/SubRegions/Patches
LEFT OUTER JOIN (-- COMPANY LEVEL
                SELECT  C.FKEmployeeID as EMPLID,    /* THIS SUB QUERY REFERENCES THE TEMP TABLE TO BRING BACK THE AMOUNT NEGATIVE COMMENTS AT EACH RESTAURANT VISIT IN A QUARTER*/
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ1Date THEN 1 ELSE 0 END) AS Q1NegComments, --- MOST COMPLETED QUARTER TWO QUARTERS IN ARREARS
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS Q2NegComments  --- MOST COMPLETED PRIOR QUARTER
						FROM #RVT
				INNER JOIN dbo.tblStores S
				ON #RVT.StoreNUmber = S.PKStoreID
				INNER JOIN dbo.tblEntityHierarchy eh
				ON S.FKEntityID = EH.FKEntityID
				INNER JOIN #Company C
                ON eh.FKEntityLevel1ID = C.FKEntityID	
				GROUP BY C.FKEmployeeID

				UNION ALL 
				-- REGION LEVEL
                SELECT  R.FKRDID as EMPLID,    /* THIS SUB QUERY REFERENCES THE TEMP TABLE TO BRING BACK THE AMOUNT NEGATIVE COMMENTS AT EACH RESTAURANT VISIT IN A QUARTER*/
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ1Date THEN 1 ELSE 0 END) AS Q1NegComments, --- MOST COMPLETED QUARTER TWO QUARTERS IN ARREARS
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS Q2NegComments  --- MOST COMPLETED PRIOR QUARTER
						FROM #RVT
				INNER JOIN dbo.tblStores S
				ON #RVT.StoreNUmber = S.PKStoreID
				INNER JOIN dbo.tblEntityHierarchy eh
				ON S.FKEntityID = EH.FKEntityID
				INNER JOIN #Regions R
				ON EH.FKEntityLevel3ID = R.FKEntityID
				GROUP BY R.FKRDID

				UNION ALL 
				-- SUB-REGION LEVEL
				SELECT  S2.FKODID as EMPLID,   /* THIS SUB QUERY REFERENCES THE TEMP TABLE TO BRING BACK THE AMOUNT NEGATIVE COMMENTS AT EACH RESTAURANT VISIT IN A QUARTER*/
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ1Date THEN 1 ELSE 0 END) AS Q1NegComments, --- MOST COMPLETED QUARTER TWO QUARTERS IN ARREARS
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS Q2NegComments  --- MOST COMPLETED PRIOR QUARTER
				FROM #RVT
				INNER JOIN dbo.tblStores S
				ON #RVT.StoreNUmber = S.PKStoreID
				INNER JOIN dbo.tblEntityHierarchy eh
				ON S.FKEntityID = EH.FKEntityID
				INNER JOIN #SubRegions S2
				ON EH.FKEntityLevel5ID = S2.FKEntityID
				GROUP BY S2.FKODID

				UNION ALL 
				-- PATCH LEVEL
				SELECT  p.FKEmployeeID as EMPLID,    /* THIS SUB QUERY REFERENCES THE TEMP TABLE TO BRING BACK THE AMOUNT NEGATIVE COMMENTS AT EACH RESTAURANT VISIT IN A QUARTER*/
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ1Date THEN 1 ELSE 0 END) AS Q1NegComments, --- MOST COMPLETED QUARTER TWO QUARTERS IN ARREARS
						SUM(CASE WHEN #RVT.TONE = 2 AND #RVT.SubmitDate = #RVT.MaxQ2Date THEN 1 ELSE 0 END) AS Q2NegComments  --- MOST COMPLETED PRIOR QUARTER
				FROM #RVT
				INNER JOIN dbo.tblStores S
				ON #RVT.StoreNUmber = S.PKStoreID
				INNER JOIN dbo.tblEntityHierarchy eh
				ON S.FKEntityID = EH.FKEntityID
				INNER JOIN #Patches P
				ON EH.FKEntityLevel7ID = P.FKEntityID
				GROUP BY P.FKEmployeeID
				) Comments
ON FEO.EmployeeID = Comments.EMPLID

WHERE FEO.Period = @Period
GROUP BY feo.Period,
         feo.EmployeeID,
		 CASE WHEN Position.Position IS NULL AND FEO.EMPLOYEEID = 124 THEN 'All Company' ELSE Position.Position END,
         RestPct.EntityCnt,
		 GreenStores.GreenCnt,
		 feo.EntityName,
		 TimeInPOS.TimeInPOS,
		 FED.TDRestaurateurPromos, 
	     FED.FLRestaurateurPromos,
		 FED.TDTLPromos,
         FED.TDATLPromos,
	     FED.FLATLPromos,
		 CASE WHEN AtModel.EMPLID IS NOT NULL THEN AtModel.RestaurantsAtModel END,
	     CASE WHEN AtModel.EMPLID IS NOT NULL THEN AtModel.Restaurants END,
	     CAST(CASE WHEN AtModel.EMPLID IS NOT NULL THEN AtModel.RestaurantsAtModel END/CASE WHEN AtModel.EMPLID IS NOT NULL THEN AtModel.Restaurants END as numeric),
		 OpsAudit.AvgMostRecentOpsAuditScore,       
	     IntHirePct.YTDInternalHirePct,	   
	     ProjvsActSales.ProjvsActSales,	   
	     KMTermPct.KMTermPct,       
	     RecStaffingPct.RecStaffingPct,       
	     NinetyDayTurnoverPct.NinetyDayTurnoverPct,       
	     HundredPctAuditPct.HundredPctAuditPct,      
	     FourPillarScore.FourPillarScore,      
	     AvgCashHandling.AvgCashHandling,      
	     CDAuditPCT.CDAuditPCT,      
	     FieldLeaderPct.FieldLeaderPct,       
	     RestPct.RestPct
--------------------------------------------
GO

