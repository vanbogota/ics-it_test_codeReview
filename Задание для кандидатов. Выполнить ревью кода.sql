/*
	В начале скрипта объекта необходимо писать поясняющий комментарий;
	Для того, чтобы повторное выполнение скрипта не приводило к возникновению
ошибки, необходимо проверять существование в БД создаваемого объекта
*/
create procedure syn.usp_ImportFileCustomerSeasonal
	@ID_Record int
as
set nocount on
begin
	declare @RowCount int = (select count(*) from syn.SA_CustomerSeasonal)
	/* 
		Для объявления переменных declare используется один раз. Дальнейшее
	переменные перечисляются через запятую с новой строки, если явно не требуется
	писать declare
	*/
	declare @ErrorMessage varchar(max) 

-- Комментарий пишется непосредственно над строкой кода
-- Проверка на корректность загрузки
	if not exists (
	-- В условных операторах весь блок смещается на 1 отступ
	select 1
	from syn.ImportFile as f
	where f.ID = @ID_Record
		and f.FlagLoaded = cast(1 as bit)
	)	
	-- if и else с begin/end должны быть на одном уровне
		begin 
			set @ErrorMessage = 'Ошибка при загрузке файла, проверьте корректность данных'

			raiserror(@ErrorMessage, 3, 1)
			-- пропущена пустая строка перед return. Пустыми строками отделяются разные логические блоки кода
			return 
		end
	
	/*
		Ключевые слова, названия системных функций и все операторы пишутся со строчной буквы;
		При создании объектов нужен пробел после названия объекта;
	*/
	CREATE TABLE #ProcessedRows(ActionType varchar(255), ID int)
	
	--Чтение из слоя временных данных
	select
		cc.ID as ID_dbo_Customer
		,cst.ID as ID_CustomerSystemType
		,s.ID as ID_Season
		,cast(sa.DateBegin as date) as DateBegin
		,cast(sa.DateEnd as date) as DateEnd
		,cd.ID as ID_dbo_CustomerDistributor
		,cast(isnull(sa.FlagActive, 0) as bit) as FlagActive
	into #CustomerSeasonal
	-- Алиас задается с помощью ключевого слова as
	from syn.SA_CustomerSeasonal cs
		-- Все виды join должны указываться явно		
		join dbo.Customer as cc on cc.UID_DS = sa.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
		join dbo.Season as s on s.Name = sa.Season
		join dbo.Customer as cd on cd.UID_DS = sa.UID_DS_CustomerDistributor
			and cd.ID_mapping_DataSource = 1
		-- При соединение двух таблиц, сперва после on указываем поле присоединяемой таблицы
		join syn.CustomerSystemType as cst on sa.CustomerSystemType = cst.Name
	where try_cast(sa.DateBegin as date) is not null
		and try_cast(sa.DateEnd as date) is not null
		and try_cast(isnull(sa.FlagActive, 0) as bit) is not null
	
	-- Для комментариев в несколько строк используется конструкция /* */
	-- Определяем некорректные записи
	-- Добавляем причину, по которой запись считается некорректной
	select
		-- Дана ссылка на не обявленный алиас.
		sa.*
		,case
			-- При написании конструкции с case, необходимо, чтобы when был под case с 1 отступом, then с 2 отступами			
			when cc.ID is null then 'UID клиента отсутствует в справочнике "Клиент"'
			when cd.ID is null then 'UID дистрибьютора отсутствует в справочнике "Клиент"'
			when s.ID is null then 'Сезон отсутствует в справочнике "Сезон"'
			when cst.ID is null then 'Тип клиента в справочнике "Тип клиента"'
			when try_cast(sa.DateBegin as date) is null then 'Невозможно определить Дату начала'
			when try_cast(sa.DateEnd as date) is null then 'Невозможно определить Дату начала'
			when try_cast(isnull(sa.FlagActive, 0) as bit) is null then 'Невозможно определить Активность'
		end as Reason
	into #BadInsertedRows
	from syn.SA_CustomerSeasonal as cs
	-- Все виды join пишутся с 1 отступом
	left join dbo.Customer as cc on cc.UID_DS = sa.UID_DS_Customer
		and cc.ID_mapping_DataSource = 1
	left join dbo.Customer as cd on cd.UID_DS = sa.UID_DS_CustomerDistributor and cd.ID_mapping_DataSource = 1
	left join dbo.Season as s on s.Name = sa.Season
	left join syn.CustomerSystemType as cst on cst.Name = sa.CustomerSystemType
	where cc.ID is null
		or cd.ID is null
		or s.ID is null
		or cst.ID is null
		or try_cast(sa.DateBegin as date) is null
		or try_cast(sa.DateEnd as date) is null
		or try_cast(isnull(sa.FlagActive, 0) as bit) is null
-- Лишние пустые строки перед end
	
		
end
