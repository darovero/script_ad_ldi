#######################################################
# Este script realiza el levantamiento de informacion #
# de Active Directory, DNS y GPOs. Adicional ayuda a  #
# la construccion del documento de diseño.            #
#######################################################

# Crear Folder donde se almacenara la info
New-Item "C:\AD_LDI" -itemType Directory

# Variables
$loc = "C:\tmp\"
$dn = ‘DC=ivti,DC=loc’


### ACTIVE DIRECTORY ###

Write "********** ACTIVE DIRECTORY ***********" "`n" | Out-File $loc’Active_Directory_LDI.txt’
# Get FSMO Roles
Write ">> FSMO ROLES" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
netdom query fsmo | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Replication Type
Write ">> REPLICATION TYPE" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-Service DFSR | select Name,DisplayName,Status | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-Service NTFSR | select Name,DisplayName,Status | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Forest
Write ">> FOREST" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADForest | select name,rootdomain,forestmode,schemamaster,domainnamingmaster,domains,globalcatalogs | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Domain
Write ">> DOMAIN" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADDomain | select name,dnsroot,domainmode,pdcemulator,ridmaster,infrastructuremaster,netbiosname,childdomains,ReplicaDirectoryServers | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Domain Controllers
Write ">> DOMAIN CONTROLLERS" | Out-File $loc’Active_Directory_LDI.txt’ -Append
$getdomain = [System.Directoryservices.Activedirectory.Domain]::GetCurrentDomain() 
$getdomain | ForEach-Object {$_.DomainControllers} |  
ForEach-Object { 
  $hEntry= [System.Net.Dns]::GetHostByName($_.Name) 
  New-Object -TypeName PSObject -Property @{ 
      Name = $_.Name 
      IPAddress = $hEntry.AddressList[0].IPAddressToString 
     } 
} | Out-File $loc’Active_Directory_LDI.txt’ -Append


# Get OUs Structure
Write "`n" ">> OUs STRUCTURE" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADOrganizationalUnit -filter * | select Name,DistinguishedName | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Users
Write "`n" ">> USERS (Users.csv)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
$usersList = Get-ADUser -Filter * -searchbase $dn -Properties * | Select Name,DistinguishedName,@{n='OrganizationalUnit';e={$_.distinguishedName -replace '^.+?,(CN|OU|DC.+)','$1'}},SamAccountName,Enabled,LastLogonDate,@{n='LastLogonDays';e={(New-TimeSpan $_.LastLogonDate $(Get-Date)).Days}},PasswordLastSet,@{n='PasswordAge';e={(New-TimeSpan $_.PasswordLastSet $(Get-Date)).Days}},PasswordNeverExpires,SID
$usersList | export-csv $loc’Users.csv’ -NoTypeInformation -Encoding Unicode

# Get Computers
Write "`n" ">> COMPUTERS (Computers.csv)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADComputer -Filter * -Property * | Select Name,DistinguishedName,OperatingSystem,OperatingSystemVersion,ipv4Address,Enabled,LastLogonDate,@{n='LastLogonDays';e={(New-TimeSpan $_.LastLogonDate $(Get-Date)).Days}} | export-csv $loc'Computers.csv' -NoTypeInformation -Encoding Unicode

# Get Groups
Write "`n" ">> GROUPS (Groups.csv)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
#// Start of script
#// Get year and month for csv export file
#// $DateTime = Get-Date -f "yyyy-MM"

#// Set CSV file name
$CSVFile = $loc+"Groups"+".csv"

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
	$MembersArr = Get-ADGroup -filter {Name -eq $ADGroup.Name} | Get-ADGroupMember | select Name
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
Write "`n" ">> REPLICATION STATE" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
repadmin /replsum | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Sites & Subnets
Write "`n" "`n" ">> SITES & SUBNETS - Export CSV (subnet.csv)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append

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
Write ">> REPLICATE CONNECTION - Export CSV (Repl_Connetion.csv)" "`n" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADReplicationConnection -Filter * | select autogenerated,name,replicatefromdirectoryserver,replicatetodirectoryserver | Export-CSV $loc’Repl_Connetion.csv’ -NoTypeInformation -Encoding Unicode
 
# Get Site Link
Write "`n" "`n" ">> SITE LINK"  "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADReplicationSiteLink -Filter * | select name,cost,replicationfrequencyinminutes  | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get ADTrust
Write "`n" "`n" ">> AD TRUST"  "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-ADTrust -Filter * | Select Name,source,target,direction | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get NTP
Write ">> NTP" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
W32tm /query /peers| Out-File $loc’Active_Directory_LDI.txt’ -Append
				

### DNS ###

Write  "`n" "*********** DNS ***********" "`n" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get DNS Information
Write ">> DNS ZONES" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-DnsServerZone | select Zonename,ZoneType,IsDsIntegrated | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get DNS Forwarders
Write ">> DNS Forwarders" | Out-File $loc’Active_Directory_LDI.txt’ -Append
Get-DnsServerForwarder | select IPAddress | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get Condicional Forwarders
Write ">> CONDITIONAL FORWARDERS" | Out-File $loc’Active_Directory_LDI.txt’ -Append
gwmi -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone -Filter "ZoneType = 4" |Select -Property @{n='Name';e={$_.ContainerName}}, @{n='DsIntegrated';e={$_.DsIntegrated}}, @{n='MasterServers';e={([string]::Join(',', $_.MasterServers))}} | Out-File $loc’Active_Directory_LDI.txt’ -Append


### GPOs ###

Write  "`n" "***	******** GPOs ***********" "`n" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append

# Get GPOs
Write ">> GPOs - Export CSV (gpos.csv)" "`n" | Out-File  $loc’Active_Directory_LDI.txt’ -Append
Get-GPO -All | select displayname,gpostatus,creationtime,modificationtime | Export-CSV $loc\gpos.csv -NoTypeInformation -Encoding Unicode

# Export GPOs to HTML
Write ">> Export GPOs to HTML (Folder GPOs_HTML)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
New-Item -ItemType Directory -Force -Path $loc’GPOs_HTML’
Get-GPO -all | % { Get-GPOReport -GUID $_.id -ReportType HTML -Path "$loc\GPOs_HTML\$($_.displayName).html" }

# Backup GPOs
Write ">> Backup GPOs (Folder GPOs_BK)" "`n" | Out-File $loc’Active_Directory_LDI.txt’ -Append
New-Item -ItemType Directory -Force -Path $loc\GPOs_BK
Get-GPO -All | Backup-GPO -Path $loc\GPOs_BK