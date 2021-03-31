use CowManager
go

-- dirty hack, but otherwise these users with super-support rights are unknown to cowmanager.api.

insert into CowManager.Gebruiker 
select
	null, --contactid,
	id.username, --Gebruikersnaam,
	id.Email,
	null, -- FK_Gebruiker_Parent,
	getdate(), --dCreate
	getdate() --dModify
from [CowManager.Identity].[dbo].[AspNetUsers] id
left outer join CowManager.Gebruiker g on g.Gebruikersnaam = id.username
where g.PK_Gebruiker is null
and (id.Email like '%@agis.nl' or id.Email like '%@cowmanager.com')
and id.lastlogindate >'20180101'

