#########################################################################
# This script provides information about Active Directory, DNS, GPOs:
##### ACTIVE DIRECTORY INFO #####
# * Get FSMO Roles
# * Get Replication Type
# * Get Forest
# * Get Domain
# * Get Domain Controllers
#* Get OUs Structure
#* Get Users
#* Get Computers
#* Get Groups and Members
#* Get Replication State
#* Get Sites & Subnets
#* Replicate Connetion
#* Get Site Link
#* Get ADTrust
#* Get NTP
#
##### DNS INFO #####
#* Get DNS Zones
#* Get DNS Forwarders
#* Get Conditional Forwarders
#
##### GPOs INFO #####
#* Get GPOs
#* Export GPOs to HTML
#* Backup GPOs
#########################################################################

# Import modules from Active Directory and Group Policy
Import-Module activedirectory
Import-Module grouppolicy

# Variables
$loc = "C:\AD_LDI\"
$dn_users = ‘OU=Bogota,DC=ivti,DC=loc’
$dn_computers = ‘OU=Bogota,DC=ivti,DC=loc’
$ous_specific = ‘OU=Servers,DC=ivti,DC=loc’
$dc_servername = "dc1601.ivti.loc"


# Create folder where the info will be stored
New-Item "C:\AD_LDI\" -itemType Directory

# Start Event Log
Start-Transcript ("C:\AD_LDI\ad_ldi_Log {0:yyyyMMdd - HHmm}.txt" -f (Get-Date))


##### ACTIVE DIRECTORY INFO #####

Write-Output "********** ACTIVE DIRECTORY INFO ***********" "`n" | Out-File $loc’Active_Directory_LDI.txt’
# Get FSMO Roles
Write-Output ">> FSMO ROLES" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
netdom query fsmo | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Replication Type
Write-Output ">> REPLICATION TYPE" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-Service DFSR -ComputerName $dc_servername | Select-Object Name,DisplayName,Status | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-Service NTFSR -ComputerName $dc_servername | Select-Object Name,DisplayName,Status | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Forest
Write-Output ">> FOREST" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADForest | Select-Object name,rootdomain,forestmode,schemamaster,domainnamingmaster,domains,globalcatalogs | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Domain
Write-Output ">> DOMAIN" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADDomain | Select-Object name,dnsroot,domainmode,pdcemulator,ridmaster,infrastructuremaster,netbiosname,childdomains,ReplicaDirectoryServers | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Domain Controllers
Write-Output ">> DOMAIN CONTROLLERS" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADDomainController -Filter * | Select-Object hostname,IPv4Address,OperatingSystem,OperatingSystemVersion | Out-File $loc’Active_Directory_LDI.txt’ -Append


# Get OUs Structure
Write-Output "`n" ">> OUs STRUCTURE" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADOrganizationalUnit -Filter * -SearchBase $ous_specific | Select-Object Name,DistinguishedName | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Users
Write-Output "`n" ">> USERS (Users.csv)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
$usersList = Get-ADUser -Filter * -searchbase $dn_users -Properties * -SearchScope Subtree | Select-Object Name,DistinguishedName,@{n='OrganizationalUnit';e={$_.distinguishedName -replace '^.+?,(CN|OU|DC.+)','$1'}},SamAccountName,Enabled,LastLogonDate,@{n='LastLogonDays';e={(New-TimeSpan $_.LastLogonDate $(Get-Date)).Days}},PasswordLastSet,@{n='PasswordAge';e={(New-TimeSpan $_.PasswordLastSet $(Get-Date)).Days}},PasswordNeverExpires,SID
$usersList | export-csv $loc’Users.csv’ -NoTypeInformation -Encoding Unicode

# Get Computers
Write-Output "`n" ">> COMPUTERS (Computers.csv)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADComputer -Filter * -Property * -searchbase $dn_computers | Select-Object Name,DistinguishedName,OperatingSystem,OperatingSystemVersion,ipv4Address,Enabled,LastLogonDate,@{n='LastLogonDays';e={(New-TimeSpan $_.LastLogonDate $(Get-Date)).Days}} | export-csv $loc'Computers.csv' -NoTypeInformation -Encoding Unicode

# Get Groups and Members
Write-Output "`n" ">> GROUPS & MEMBERS (Groups.csv)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
#// Start of script
#// Get year and month for csv export file
#// $DateTime = Get-Date -f "yyyy-MM"

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

# Get Replication State
Write-Output "`n" ">> REPLICATION STATE" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
repadmin /replsum | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Sites & Subnets
Write-Output "`n" "`n" ">> SITES & SUBNETS - Export CSV (subnet.csv)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append

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

# Replicate Connetion 
Write-Output ">> REPLICATE CONNECTION - Export CSV (Repl_Connetion.csv)" "`n" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADReplicationConnection -Filter * | Select-Object autogenerated,name,replicatefromdirectoryserver,replicatetodirectoryserver | Export-CSV $loc’Repl_Connetion.csv’ -NoTypeInformation -Encoding Unicode
 
# Get Site Link
Write-Output "`n" "`n" ">> SITE LINK"  "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADReplicationSiteLink -Filter * | Select-Object name,cost,replicationfrequencyinminutes  | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get ADTrust
Write-Output "`n" "`n" ">> AD TRUST"  "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADTrust -Filter * | Select-Object Name,source,target,direction | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get NTP
Write-Output ">> NTP" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
W32tm /query /peers| Out-File $loc’Active_Directory_LDI.txt’ -Append
				



##### DNS INFO #####

Write-Output  "`n" "*********** DNS INFO ***********" "`n" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get DNS Zones
Write-Output ">> DNS ZONES" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-DnsServerZone -ComputerName $dc_servername | Select-Object Zonename,ZoneType,IsDsIntegrated | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get DNS Forwarders
Write-Output ">> DNS Forwarders" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-DnsServerForwarder -ComputerName $dc_servername | Select-Object IPAddress | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Condicional Forwarders
Write-Output-Output ">> CONDITIONAL FORWARDERS" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
$list = (Get-ADForest).GlobalCatalogs
$list | ForEach-Object {
	$dcname = $_
	$dcname
	Get-WmiObject -computername $dcname -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone -Filter "ZoneType = 4" | Select-Object -Property @{n='Name';e={$_.ContainerName}}, @{n='DsIntegrated';e={$_.DsIntegrated}}, @{n='MasterServers';e={([string]::Join(',', $_.MasterServers))}} | Format-Table 
} | Out-File $loc’Active_Directory_LDI.txt’ -Append





##### GPOs INFO #####

Write-Output  "`n" "***	******** GPOs INFO ***********" "`n" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get GPOs
Write-Output ">> GPOs - Export CSV (gpos.csv)" "`n" | Out-File  $loc’Active_Directory_LDI.txt’ -Append
Get-GPO -All | Select-Object displayname,gpostatus,creationtime,modificationtime | Export-CSV $loc\gpos.csv -NoTypeInformation -Encoding Unicode

# Export GPOs to HTML
Write-Output ">> Export GPOs to HTML (Folder GPOs_HTML)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
New-Item -ItemType Directory -Force -Path $loc’GPOs_HTML’
Get-GPO -all | ForEach-Object { Get-GPOReport -GUID $_.id -ReportType HTML -Path "$loc\GPOs_HTML\$($_.displayName).html" }

# Backup GPOs
Write-Output ">> Backup GPOs (Folder GPOs_BK)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
New-Item -ItemType Directory -Force -Path $loc\GPOs_BK
Get-GPO -All | Backup-GPO -Path $loc\GPOs_BK


#Stop Event Log
Stop-Transcript