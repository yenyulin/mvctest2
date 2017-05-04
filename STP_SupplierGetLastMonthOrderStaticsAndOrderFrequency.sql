USE [DingYaoERP]
GO
/****** Object:  StoredProcedure [dbo].[STP_CustomerGetLastMonthOrderStaticsAndPurchaseFrequency]    Script Date: 2017/4/26 下午 03:05:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =========================================================
-- Create User:Alex
-- Create Date:2017/04/26
-- Update User:Alex
-- Update Date:2017/04/26
-- Description:取得所有供應商上個月的總訂購金額及叫貨頻率
-- =========================================================
alter Proc [dbo].[STP_SupplierGetLastMonthOrderStaticsAndOrderFrequency]
(
	@Year int,
	@Month int
)
as
	declare @DtString nvarchar(30);
	set @DtString= cast(@Year as nvarchar(20))+'/'+cast(@Month as nvarchar(5))+'/01';

	select a.SupplierID,b.SumMoney,OrderDueDateCount,OrderCount,StockInWeight1,StockInWeight2 from 
	(
		select SupplierID,CreateDate from TB_Supplier 
		where cast(CreateDate as datetime) <  DATEADD(month,1,cast(  @DtString as datetime))  
	) a
	left join
	(
		select SupplierID,SumMoney=Sum(SumMoney) from
		(
			select a.SumMoney,SupplierID,Dt=StockInDate from TB_AccountsPayable a left join TB_StockIN b on a.AccountsPayableNo=b.StockInID
			where AccountsPayableType='進貨單'
			union
			select SumMoney,SupplierID,Dt from
			(
			select a.*,b.SupplierID,Dt=MPOrderDate,ItemIndex = ROW_NUMBER() OVER(PARTITION BY AccountsPayableID ORDER BY AccountsPayableID) from TB_AccountsPayable a left join TB_MPStockInNoStockInProductID b on a.AccountsPayableNo=b.MPStockInNo
			left join TB_MPStockInProduct c on b.MPStockInProductID=c.MPStockInProductID left join TB_MPOrder d on c.MPOrderID=d.MPOrderID
			where AccountsPayableType='市購進貨'
			)g where ItemIndex=1
			union
			select a.SumMoney,SupplierID,Dt=SupplierReturnBatchDate from TB_AccountsPayable a left join TB_SupplierReturn b on a.AccountsPayableNo=b.SupplierReturnID
			where AccountsPayableType='進貨退回'
			union
			--市購進貨
			select a.SumMoney,SupplierID,Dt=MarketReturnDate from TB_AccountsPayable a left join TB_MarketReturn b on a.AccountsPayableNo=b.MarketReturnID
			where AccountsPayableType='市購退回'

		)x
		where Year(Dt)=@Year and Month(Dt)=@Month
		group by SupplierID
	)b on a.SupplierID=b.SupplierID
	left join
	(		
		select SupplierID,OrderCount=Count(*), OrderDueDateCount= ROUND( CAST( 26.000/Count(*) as decimal(18,2)) ,2) from (
		
			select SupplierID,Dt from
			(
				select SupplierID,Dt=StockInDate from TB_AccountsPayable a left join TB_StockIN b on a.AccountsPayableNo=b.StockInID
				where AccountsPayableType='進貨單'
				union
				select SupplierID,Dt from
				(
					select a.*,b.SupplierID,Dt=MPOrderDate,ItemIndex = ROW_NUMBER() OVER(PARTITION BY AccountsPayableID ORDER BY AccountsPayableID) from TB_AccountsPayable a left join TB_MPStockInNoStockInProductID b on a.AccountsPayableNo=b.MPStockInNo
					left join TB_MPStockInProduct c on b.MPStockInProductID=c.MPStockInProductID left join TB_MPOrder d on c.MPOrderID=d.MPOrderID
					where AccountsPayableType='市購進貨'
				)g where ItemIndex=1
			)yy 
			where  Year(Dt)=@Year and Month(Dt)=@Month

		)x group by SupplierID
	)c on a.SupplierID=c.SupplierID
	left join 
	(
		select SupplierID,StockInWeight1=Sum(Qty*CustomerUnitWeight) from 
		(
			--進貨重量
			select a.SupplierID,c.ProductCode,c.TradeUnit,Qty=b.StockInQty,CustomerUnitWeight from TB_StockIn a left join TB_StockInProduct b on a.StockInID=b.StockInID
			left join TB_POrderProduct c on b.POrderProductID=c.POrderProductID
			left join TB_Product p on c.ProductCode=p.ProductCode
			where  Year(StockInDate)=@Year and Month(StockInDate)=@Month
			union
			--市購進貨重量
			select SupplierID,m2.ProductCode,MPStockInUnit,Qty=MPStockInQty,CustomerUnitWeight from 
			(
				select MPOrderID from TB_MPOrder 
				where MPOrderStatus in ('已完成') 
				and  Year(MPOrderDate)=@Year and Month(MPOrderDate)=@Month				
			)m1 left join TB_MPStockInProduct m2 on m1.MPOrderID=m2.MPOrderID
			left join TB_MPStockInNoStockInProductID m3 on m2.MpStockInProductID=m3.MpStockInProductID
			left join TB_Product p on m2.ProductCode=p.ProductCode
		)weight1 group by SupplierID
	)d on a.SupplierID=d.SupplierID
	left join 
	(
		select SupplierID,StockInWeight2=Sum(Qty*CustomerUnitWeight) from 
		(
			--進貨退回
			select SupplierID,s.ProductCode,Qty=SupplierReturnQty,CustomerUnitWeight from TB_SupplierReturn a 
			left join TB_SupplierReturnProduct b on a.SupplierReturnID=b.SupplierReturnID
			left join TB_StockLog s on b.StockLogID=s.StockLogID
			left join TB_Product p on s.ProductCode=p.ProductCode
			where  Year(SupplierReturnBatchDate)=@Year and Month(SupplierReturnBatchDate)=@Month
			union
			--市購退回
			select SupplierID,s.ProductCode,Qty=MarketReturnQty,CustomerUnitWeight from TB_MarketReturn a 
			left join TB_MarketReturnProduct b on a.MarketReturnID=b.MarketReturnID
			left join TB_StockLog s on b.StockLogID=s.StockLogID
			left join TB_Product p on s.ProductCode=p.ProductCode
			where  Year(MarketReturnDate)=@Year and Month(MarketReturnDate)=@Month

		)weight2 group by SupplierID
	)e on a.SupplierID=e.SupplierID