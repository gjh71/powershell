Select Max(PercentUsed)
From
(
	SELECT	name As [FileName]
		,	Convert(decimal(5,2), Round(100.0 * FILEPROPERTY(name, 'SpaceUsed') / max_size, 2)) As PercentUsed
	FROM sys.database_files
	Where	type_desc = 'ROWS'
	And		max_size > 0
) u