#########################################################################
# This script provides information about Active Directory, DNS, GPOs.
#########################################################################
##### ACTIVE DIRECTORY INFO #####
# * Get FSMO Roles
# * Get Replication Type
# * Get Forest
# * Get Domain
# * Get Domain Controllers
# * Get Optional Features
# * Get OUs Structure
# * Get Users
# * Get Computers
# * Get Groups and Members
# * Get Replication Status
# * Get Sites & Subnets
# * Get Replicate Connetion
# * Get Site Link
# * Get ADTrust
# * Get NTP
#
##### DNS INFO #####
# * Get DNS Zones
# * Get DNS Forwarders
# * Get Conditional Forwarders
#
##### GPOs INFO #####
# * Get GPOs
# * Export GPOs to HTML
# * Backup GPOs
#########################################################################

# VARIABLES

# Define the path where the information is stored
$loc = "C:\AD_LDI\"
# Define the file name with extension .txt
$doc = "Active_Directory_LDI.txt"
# Define the OU organizational unit or the tree root where users are stored. You must enter the Distinguished Names (example: Tree Root "DC=ivti,DC=loc" or OU specifies "OU=Bogota,DC=ivti,DC=loc")
$dn_users = "OU=Bogota,DC=ivti,DC=loc"
# Define the OU organizational unit or the tree root where computers are stored. You must enter the Distinguished Names (example: Tree Root "DC=ivti,DC=loc" or OU specifies "OU=Bogota,DC=ivti,DC=loc")
$dn_computers = "OU=Bogota,DC=ivti,DC=loc"
# Define the OU organizational unit or the tree root of the structure of the OUs. You must enter the Distinguished Names (example: Tree Root "DC=ivti,DC=loc" or OU specifies "OU=Servers,DC=ivti,DC=loc")
$ous_structure = "OU=Servers,DC=ivti,DC=loc"
# Define the Domain Controller to which you are going to connect to extract the information (It is recommended that it be the DC that has the FSMO PDC Role).
$dc_servername = "dc1601.ivti.loc"

# IMPORT MODULES FROM ACTIVE DIRECTORY AND GROUP POLICY
Import-Module activedirectory
Import-Module grouppolicy


# CREATE FOLDER WHERE THE INFORMATION WILL BE STORED
if ((Test-Path -Path $loc -PathType Container) -eq $false) {New-Item -Type Directory -Force -Path $loc}

# START EVENT LOG
Start-Transcript -Path $loc’ad_ldi_log.txt’


##### ACTIVE DIRECTORY INFO #####

Write-Output "********** ACTIVE DIRECTORY INFO ***********" "`n" | Out-File $loc$doc

# GET FSMO ROLES
Write-Output ">>>> FSMO ROLES <<<<" "`n" | Out-File $loc$doc -Append
Get-ADDomainController -Filter * | Select-Object Name, Domain, Forest, OperationMasterRoles | Where-Object {$_.OperationMasterRoles} | Out-File $loc$doc -Append

# GET REPLICATION TYPE
Write-Output "`n" ">>>> REPLICATION TYPE <<<<" "`n" | Out-File $loc$doc -Append
$servicename = "DFSR"
if (Get-Service $servicename -ComputerName $dc_servername -ErrorAction SilentlyContinue)
{
    Write-Output "$servicename Replication Running" | Out-File $loc$doc -Append
}

else {
    Write-Output "$servicename not found" | Out-File $loc$doc -Append
}

# GET FOREST
Write-Output "`n" "`n" ">>>> FOREST <<<<" | Out-File $loc$doc -Append
Get-ADForest | Select-Object name,rootdomain,forestmode,schemamaster,domainnamingmaster,domains,globalcatalogs | Out-File $loc$doc -Append

# GET DOMAIN
Write-Output ">>>> DOMAIN <<<<" | Out-File $loc$doc -Append
Get-ADDomain | Select-Object name,dnsroot,domainmode,pdcemulator,ridmaster,infrastructuremaster,netbiosname,childdomains,ReplicaDirectoryServers | Out-File $loc$doc -Append

# GET DOMAIN CONTROLLERS
Write-Output ">>>> DOMAIN CONTROLLERS <<<<" | Out-File $loc$doc -Append
Get-ADDomainController -Filter * | Select-Object hostname,IPv4Address,OperatingSystem,OperatingSystemVersion | Out-File $loc$doc -Append

# GET OPTIONAL FEATURES
Write-Output ">>>> OPTIONAL FEATURES <<<<" | Out-File $loc$doc -Append
Get-ADOptionalFeature -Server $dc_servername -filter * | Select-Object name  | Out-File $loc$doc -Append

# GT OUs STRUCTURE
Write-Output "`n" ">>>> OUs STRUCTURE <<<<" "`n" | Out-File $loc$doc -Append
Get-ADOrganizationalUnit -Filter * -SearchBase $ous_structure | Select-Object Name,DistinguishedName | Out-File $loc$doc -Append

# GET USERS
Write-Output "`n" ">>>> USERS (Export to Users.csv) <<<<" "`n" | Out-File $loc$doc -Append
$usersList = Get-ADUser -Filter * -searchbase $dn_users -Properties * -SearchScope Subtree | Select-Object Name,DistinguishedName,@{n='OrganizationalUnit';e={$_.distinguishedName -replace '^.+?,(CN|OU|DC.+)','$1'}},SamAccountName,Enabled,LastLogonDate,@{n='LastLogonDays';e={(New-TimeSpan $_.LastLogonDate $(Get-Date)).Days}},PasswordLastSet,@{n='PasswordAge';e={(New-TimeSpan $_.PasswordLastSet $(Get-Date)).Days}},PasswordNeverExpires,SID
$usersList | export-csv $loc’Users.csv’ -NoTypeInformation -Encoding Unicode

# GET COMPUTERS
Write-Output "`n" ">>>> COMPUTERS (Export to Computers.csv) <<<<" "`n" | Out-File $loc$doc -Append
Get-ADComputer -Filter * -Property * -searchbase $dn_computers | Select-Object Name,DistinguishedName,OperatingSystem,OperatingSystemVersion,ipv4Address,Enabled,LastLogonDate,@{n='LastLogonDays';e={(New-TimeSpan $_.LastLogonDate $(Get-Date)).Days}} | export-csv $loc'Computers.csv' -NoTypeInformation -Encoding Unicode

# GET GROUPS AND MEMBERS
Write-Output "`n" ">>>> GROUPS & MEMBERS (Export to Groups.csv) <<<<" "`n" | Out-File $loc$doc -Append
#// Start of script #// Get year and month for csv export file #// $DateTime = Get-Date -f "yyyy-MM"

#// Set CSV file name
$CSVFile = $loc+"Groups&Members"+".csv"

#// Create emy array for CSV data
$CSVOutput = @()

#// Get all AD groups in the domain
$ADGroups = Get-ADGroup -Filter *

#// Set progress bar variables
$i=0
$tot = $ADGroups.count

foreach ($ADGroup in $ADGroups) {
	#// Set up progress bar
	$i++
	$status = "{0:N0}" -f ($i / $tot * 100)
	Write-Progress -Activity "Exporting AD Groups" -status "Processing Group $i of $tot : $status% Completed" -PercentComplete ($i / $tot * 100)

	#// Ensure Members variable is empty
	$Members = ""

	#// Get group members which are also groups and add to string
	$MembersArr = Get-ADGroup -filter {Name -eq $ADGroup.Name} | Get-ADGroupMember | Select-Object Name
	if ($MembersArr) {
		foreach ($Member in $MembersArr) {
			$Members = $Members + "," + $Member.Name
		}
		$Members = $Members.Substring(1,($Members.Length) -1)
	}

	#// Set up hash table and add values
	$HashTab = $NULL
	$HashTab = [ordered]@{
		"Name" = $ADGroup.Name
		"Category" = $ADGroup.GroupCategory
		"Scope" = $ADGroup.GroupScope
		"Members" = $Members
	}

	#// Add hash table to CSV data array
	$CSVOutput += New-Object PSObject -Property $HashTab
}

#// Export to CSV files
$CSVOutput | Sort-Object Name | Export-Csv $CSVFile -NoTypeInformation

#// End of script

# GET REPLICATION STATUS
Write-Output "`n" ">>>> REPLICATION STATUS <<<<" "`n" | Out-File $loc$doc -Append
repadmin /replsum | Out-File $loc$doc -Append

# GET SITES & SUBNETS
Write-Output "`n" "`n" ">>>> SITES & SUBNETS (Export to subnet.csv) <<<<" "`n" | Out-File $loc$doc -Append

$sites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites
 
$sitesubnets = @()
 
foreach ($site in $sites)
{
      foreach ($subnet in $site.subnets){
         $temp = New-Object PSCustomObject -Property @{
         'Site' = $site.Name
         'Subnet' = $subnet; }
          $sitesubnets += $temp
      }
}
 
$sitesubnets | Export-CSV $loc’subnet.csv’ -NoTypeInformation -Encoding Unicode

# REPLICATE CONNETION 
Write-Output "`n" "`n" ">>>> REPLICATE CONNECTION (Export to Repl_Connetion.csv) <<<<" "`n" "`n" | Out-File $loc$doc -Append
Get-ADReplicationConnection -Filter * | Select-Object autogenerated,name,replicatefromdirectoryserver,replicatetodirectoryserver | Export-CSV $loc’Repl_Connetion.csv’ -NoTypeInformation -Encoding Unicode
 
# GET SITE LINK
Write-Output "`n" "`n" ">>>> SITE LINK <<<<"  "`n" | Out-File $loc$doc -Append
Get-ADReplicationSiteLink -Filter * | Select-Object name,cost,replicationfrequencyinminutes  | Out-File $loc$doc -Append

# GET AD TRUST
Write-Output "`n" "`n" ">>>> AD TRUST <<<<"  "`n" | Out-File $loc$doc -Append
Get-ADTrust -Filter * | Select-Object Name,source,target,direction | Out-File $loc$doc -Append

# GET NTP
Write-Output ">>>> NTP <<<<" "`n" | Out-File $loc$doc -Append
w32tm /query /computer:$dc_servername /peers | Out-File $loc$doc -Append
				



##### DNS INFO #####

Write-Output  "`n" "`n" "*********** DNS INFO ***********" "`n" "`n" | Out-File $loc$doc -Append

# GET DNS ZONES
Write-Output "`n" ">>>> DNS ZONES <<<<" "`n" | Out-File $loc$doc -Append
Get-DnsServerZone -ComputerName $dc_servername | Select-Object Zonename,ZoneType,IsDsIntegrated | Out-File $loc$doc -Append

# GET DNS FORWARDERS
Write-Output ">>>> DNS FORWARDERS <<<<" | Out-File $loc$doc -Append
Get-DnsServerForwarder -ComputerName $dc_servername | Select-Object IPAddress | Out-File $loc$doc -Append

# GET CONDITIONAL FORWARDERS
Write-Output ">>>> CONDITIONAL FORWARDERS <<<<" "`n" | Out-File $loc$doc -Append
$list = (Get-ADForest).GlobalCatalogs
$list | ForEach-Object {
	$dcname = $_
	$dcname
	Get-WmiObject -computername $dcname -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone -Filter "ZoneType = 4" | Select-Object -Property @{n='Name';e={$_.ContainerName}}, @{n='DsIntegrated';e={$_.DsIntegrated}}, @{n='MasterServers';e={([string]::Join(',', $_.MasterServers))}} | Format-Table 
} | Out-File $loc$doc -Append





##### GPOs INFO #####

Write-Output  "`n" "************ GPOs INFO ***********" "`n" "`n" | Out-File $loc$doc -Append

# GET GPOs
Write-Output ">>>> GPOs (Export to gpos.csv) <<<<" "`n" | Out-File  $loc$doc -Append
Get-GPO -All | Select-Object displayname,gpostatus,creationtime,modificationtime | Export-CSV $loc\gpos.csv -NoTypeInformation -Encoding Unicode

# EXPORT GPOs TO HTML
Write-Output ">>>> GPOs IN HTML FORMAT (Folder GPOs_HTML) <<<<" "`n" | Out-File $loc$doc -Append
New-Item -ItemType Directory -Force -Path $loc’GPOs_HTML’
Get-GPO -all | ForEach-Object { Get-GPOReport -GUID $_.id -ReportType HTML -Path "$loc\GPOs_HTML\$($_.displayName).html" }

# BACKUP GPOs
Write-Output ">>>> BACKUP GPOs (Folder GPOs_BK) <<<<" "`n" | Out-File $loc$doc -Append
New-Item -ItemType Directory -Force -Path $loc\GPOs_BK
Get-GPO -All | Backup-GPO -Path $loc\GPOs_BK


#STOP EVENT LOG
Stop-Transcript