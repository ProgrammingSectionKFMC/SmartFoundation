
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE FUNCTION [Housing].[GetListMeterSlidesPrice] 
(	
	-- Add the parameters for the function here

)
RETURNS TABLE 
AS
RETURN 
(
	select distinct

ms.buildingUtilityTypeID_FK,

--------------------------------------------------------------------------------
(select 
ms11.meterSlideMinValue

from  Housing.MeterSlide ms11
where ms11.buildingUtilityTypeID_FK = ms.buildingUtilityTypeID_FK and ms11.meterServiceTypeID_FK = 1 and ms11.meterSlideSequence = 1 ) meterSlideMinValue1,

(select 
ms12.meterSlideMaxValue
from  Housing.MeterSlide ms12
where ms12.buildingUtilityTypeID_FK = ms.buildingUtilityTypeID_FK and ms12.meterServiceTypeID_FK = 1 and ms12.meterSlideSequence = 1 ) meterSlideMaxValue1,


(select 
ms13.meterSlidePriceFactor
from  Housing.MeterSlide ms13
where ms13.buildingUtilityTypeID_FK = ms.buildingUtilityTypeID_FK and ms13.meterServiceTypeID_FK = 1 and ms13.meterSlideSequence = 1 ) SlidePriceFactor1,


----------------------------------------------------------------------------------
(select 
ms21.meterSlideMinValue

from  Housing.MeterSlide ms21
where ms21.buildingUtilityTypeID_FK = ms.buildingUtilityTypeID_FK and ms21.meterServiceTypeID_FK = 1 and ms21.meterSlideSequence = 2 ) meterSlideMinValue2,

(select 
ms22.meterSlideMaxValue
from  Housing.MeterSlide ms22
where ms22.buildingUtilityTypeID_FK = ms.buildingUtilityTypeID_FK and ms22.meterServiceTypeID_FK = 1 and ms22.meterSlideSequence = 2 ) meterSlideMaxValue2,


(select 
ms23.meterSlidePriceFactor
from  Housing.MeterSlide ms23
where ms23.buildingUtilityTypeID_FK = ms.buildingUtilityTypeID_FK and ms23.meterServiceTypeID_FK = 1 and ms23.meterSlideSequence = 2 ) SlidePriceFactor2,


----------------------------------------------------------------------------------

(select 
ms31.meterSlideMinValue

from  Housing.MeterSlide ms31
where ms31.buildingUtilityTypeID_FK = ms.buildingUtilityTypeID_FK and ms31.meterServiceTypeID_FK = 1 and ms31.meterSlideSequence = 3 ) meterSlideMinValue3,

(select 
ms32.meterSlideMaxValue
from  Housing.MeterSlide ms32
where ms32.buildingUtilityTypeID_FK = ms.buildingUtilityTypeID_FK and ms32.meterServiceTypeID_FK = 1 and ms32.meterSlideSequence = 3 ) meterSlideMaxValue3,


(select 
ms33.meterSlidePriceFactor
from  Housing.MeterSlide ms33
where ms33.buildingUtilityTypeID_FK = ms.buildingUtilityTypeID_FK and ms33.meterServiceTypeID_FK = 1 and ms33.meterSlideSequence = 3 ) SlidePriceFactor3


----------------------------------------------------------------------------------

from  Housing.MeterSlide ms
where ms.meterServiceTypeID_FK = 1 and ms.buildingUtilityTypeID_FK in(1,11,13)


Union All



select distinct

mss.buildingUtilityTypeID_FK,


--------------------------------------------------------------------------------
(select 
ms11.meterSlideMinValue

from  Housing.MeterSlide ms11
where ms11.buildingUtilityTypeID_FK = mss.buildingUtilityTypeID_FK and ms11.meterServiceTypeID_FK = 1 and ms11.meterSlideSequence = 1 ) meterSlideMinValue1,

(select 
ms12.meterSlideMaxValue
from  Housing.MeterSlide ms12
where ms12.buildingUtilityTypeID_FK = mss.buildingUtilityTypeID_FK and ms12.meterServiceTypeID_FK = 1 and ms12.meterSlideSequence = 1 ) meterSlideMaxValue1,


(select 
ms13.meterSlidePriceFactor
from  Housing.MeterSlide ms13
where ms13.buildingUtilityTypeID_FK = mss.buildingUtilityTypeID_FK and ms13.meterServiceTypeID_FK = 1 and ms13.meterSlideSequence = 1 ) SlidePriceFactor1,


----------------------------------------------------------------------------------
(select 
ms21.meterSlideMinValue

from  Housing.MeterSlide ms21
where ms21.buildingUtilityTypeID_FK = mss.buildingUtilityTypeID_FK and ms21.meterServiceTypeID_FK = 1 and ms21.meterSlideSequence = 2 ) meterSlideMinValue2,

(select 
ms22.meterSlideMaxValue
from  Housing.MeterSlide ms22
where ms22.buildingUtilityTypeID_FK = mss.buildingUtilityTypeID_FK and ms22.meterServiceTypeID_FK = 1 and ms22.meterSlideSequence = 2 ) meterSlideMaxValue2,


(select 
ms23.meterSlidePriceFactor
from  Housing.MeterSlide ms23
where ms23.buildingUtilityTypeID_FK = mss.buildingUtilityTypeID_FK and ms23.meterServiceTypeID_FK = 1 and ms23.meterSlideSequence = 2 ) SlidePriceFactor2,


----------------------------------------------------------------------------------

(select 
ms31.meterSlideMinValue

from  Housing.MeterSlide ms31
where ms31.buildingUtilityTypeID_FK = mss.buildingUtilityTypeID_FK and ms31.meterServiceTypeID_FK = 1 and ms31.meterSlideSequence = 3 ) meterSlideMinValue3,

(select 
ms32.meterSlideMaxValue
from  Housing.MeterSlide ms32
where ms32.buildingUtilityTypeID_FK = mss.buildingUtilityTypeID_FK and ms32.meterServiceTypeID_FK = 1 and ms32.meterSlideSequence = 3 ) meterSlideMaxValue3,


(select 
ms33.meterSlidePriceFactor
from  Housing.MeterSlide ms33
where ms33.buildingUtilityTypeID_FK = mss.buildingUtilityTypeID_FK and ms33.meterServiceTypeID_FK = 1 and ms33.meterSlideSequence = 3 ) SlidePriceFactor3


----------------------------------------------------------------------------------

from  Housing.MeterSlide mss
where mss.meterServiceTypeID_FK = 1 and mss.buildingUtilityTypeID_FK in(4,12,14)
)
