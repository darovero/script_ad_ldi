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
# * Get Structure OUs
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
# * Link Path GPOs
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
# Define the OU organizational unit or the tree root where Groups are stored. You must enter the Distinguished Names (example: Tree Root "DC=ivti,DC=loc" or OU specifies "OU=Groups,DC=ivti,DC=loc")
$dn_groups = "OU=Groups,DC=ivti,DC=loc"
# Define the OU organizational unit or the tree root of the structure of the OUs. You must enter the Distinguished Names (example: Tree Root "DC=ivti,DC=loc" or OU specifies "OU=Servers,DC=ivti,DC=loc")
$structure_ous = "OU=Servers,DC=ivti,DC=loc"
# Define the Domain Controller to which you are going to connect to extract the information (It is recommended that it be the DC that has the FSMO PDC Role).
$dc_servername = "dc1601.ivti.loc"

# IMPORT MODULES FROM ACTIVE DIRECTORY AND GROUP POLICY
Import-Module activedirectory
Import-Module grouppolicy


# CREATE FOLDER WHERE THE INFORMATION WILL BE STORED
if ((Test-Path -Path $loc -PathType Container) -eq $false) {New-Item -Type Directory -Force -Path $loc}
New-Item -ItemType Directory -Force -Path $loc\AD\
New-Item -ItemType Directory -Force -Path $loc\DNS\
New-Item -ItemType Directory -Force -Path $loc\GPOs\

# START EVENT LOG
Start-Transcript -Path $loc’ad_ldi_log.txt’


##### ACTIVE DIRECTORY INFO #####

Write-Output "********** ACTIVE DIRECTORY INFO ***********" "`n" "`n" | Out-File $loc$doc

# GET FSMO ROLES
Write-Output "`n" ">>>> FSMO ROLES (Export to AD/FSMO_Roles.csv) <<<<" "`n" | Out-File $loc$doc -Append
Get-ADDomainController -Filter * | Select-Object Name, Domain, Forest, @{name="OperationMasterRoles";expression={$_.OperationMasterRoles}} | Export-CSV $loc\AD\’FSMO_Roles.csv’ -NoTypeInformation -Encoding Unicode

# GET REPLICATION TYPE
Write-Output "`n" ">>>> REPLICATION TYPE (Export to AD/Replication_Type.txt) <<<<" "`n" | Out-File $loc$doc -Append
$servicename = "DFSR"
if (Get-Service $servicename -ComputerName $dc_servername -ErrorAction SilentlyContinue)
{
    Write-Output "$servicename Replication Running" | Out-File $loc\AD\’Replication_Type.txt’
}

else {
    Write-Output "$servicename not found" | Out-File $loc\AD\’Replication_Type.txt’
}

# GET FOREST
Write-Output "`n" ">>>> FOREST (Export to AD/Forest.csv) <<<<" "`n" | Out-File $loc$doc -Append
Get-ADForest | Select-Object Name,Rootdomain,Forestmode,Schemamaster,Domainnamingmaster,@{name="Domains";expression={$_.domains}},@{name="Globalcatalogs";expression={$_.globalcatalogs}} | Export-CSV $loc\AD\’Forest.csv’ -NoTypeInformation -Encoding Unicode

# GET DOMAIN
Write-Output "`n" ">>>> DOMAIN (Export to AD/Domain.csv) <<<<" "`n" | Out-File $loc$doc -Append
Get-ADDomain | Select-Object Name,Dnsroot,Domainmode,Pdcemulator,Ridmaster,Infrastructuremaster,Netbiosname,@{name="Childdomains";expression={$_.childdomains}},@{name="ReplicaDirectoryServers";expression={$_.ReplicaDirectoryServers}} | Export-CSV $loc\AD\’Domain.csv’ -NoTypeInformation -Encoding Unicode

# GET OPTIONAL FEATURES
Write-Output "`n" ">>>> OPTIONAL FEATURES (Export to AD/Optional_Features.txt <<<<" "`n" | Out-File $loc$doc -Append
Get-ADOptionalFeature -Server $dc_servername -filter * | Select-Object Name  | Export-CSV $loc\AD\’Optional_Features.csv’ -NoTypeInformation -Encoding Unicode

# GET DOMAIN CONTROLLERS
Write-Output "`n" ">>>> DOMAIN CONTROLLERS (Export to AD/Domain_Controllers.csv) <<<<" "`n" | Out-File $loc$doc -Append
Get-ADDomainController -Filter * | Select-Object Hostname,IPv4Address,OperatingSystem,OperatingSystemVersion | Export-CSV $loc\AD\’Domain_Controllers.csv’ -NoTypeInformation -Encoding Unicode

# GET STRUCTURE OUs
Write-Output "`n" ">>>> STRUCTURE OUs (Export to AD/Structure_OUs.csv) <<<<" "`n" | Out-File $loc$doc -Append
Get-ADOrganizationalUnit -Filter * -SearchBase $structure_ous | Select-Object Name,DistinguishedName | Export-Csv -Path $loc\AD\’Structure_OUs.csv’ -NoTypeInformation -Encoding Unicode

# GET USERS
Write-Output "`n" ">>>> USERS (Export to AD/Users.csv) <<<<" "`n" | Out-File $loc$doc -Append
$usersList = Get-ADUser -Filter * -searchbase $dn_users -Properties * -SearchScope Subtree | Select-Object Name,DistinguishedName,@{n='OrganizationalUnit';e={$_.distinguishedName -replace '^.+?,(CN|OU|DC.+)','$1'}},SamAccountName,Enabled,LastLogonDate,@{n='LastLogonDays';e={(New-TimeSpan $_.LastLogonDate $(Get-Date)).Days}},PasswordLastSet,@{n='PasswordAge';e={(New-TimeSpan $_.PasswordLastSet $(Get-Date)).Days}},PasswordNeverExpires,SID
$usersList | export-csv $loc\AD\’Users.csv’ -NoTypeInformation -Encoding Unicode

# GET COMPUTERS
Write-Output "`n" ">>>> COMPUTERS (Export to AD/Computers.csv) <<<<" "`n" | Out-File $loc$doc -Append
Get-ADComputer -Filter * -Property * -searchbase $dn_computers | Select-Object Name,DistinguishedName,OperatingSystem,OperatingSystemVersion,ipv4Address,Enabled,LastLogonDate,@{n='LastLogonDays';e={(New-TimeSpan $_.LastLogonDate $(Get-Date)).Days}} | export-csv $loc\AD\'Computers.csv' -NoTypeInformation -Encoding Unicode

# GET GROUPS AND MEMBERS
Write-Output "`n" ">>>> GROUPS & MEMBERS (Export to AD/Groups.csv) <<<<" "`n" | Out-File $loc$doc -Append
$Groups = Get-ADGroup -Filter * -SearchBase $dn_groups
$Results = foreach( $Group in $Groups ){
    Get-ADGroupMember -Identity $Group | ForEach-Object {
        [pscustomobject]@{
            GroupName = $Group.Name
            Name = $_.Name
            }
        }
    }
$Results| Export-Csv -Path $loc\AD\’Groups.csv’ -NoTypeInformation﻿


# GET REPLICATION STATUS
Write-Output "`n" ">>>> REPLICATION STATUS (Export to AD/Replsum.txt) <<<<" "`n"  | Out-File $loc$doc -Append
repadmin /replsum | Out-File $loc\AD\’Replsum.txt’

# GET SITES & SUBNETS
Write-Output "`n" ">>>> SITES & SUBNETS (Export to AD/Subnet.csv) <<<<" "`n"  | Out-File $loc$doc -Append
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
$sitesubnets | Export-CSV $loc\AD\’Subnet.csv’ -NoTypeInformation -Encoding Unicode

# REPLICATE CONNETION 
Write-Output "`n" ">>>> REPLICATE CONNECTION (Export to AD/Repl_Connetion.csv) <<<<" "`n"  | Out-File $loc$doc -Append
Get-ADReplicationConnection -Filter * | Select-Object autogenerated,name,replicatefromdirectoryserver,replicatetodirectoryserver | Export-CSV $loc\AD\’Repl_Connetion.csv’ -NoTypeInformation -Encoding Unicode
 
# GET SITE LINK
Write-Output "`n" ">>>> SITE LINK (Export to AD/Site_Link.csv) <<<<"  "`n" | Out-File $loc$doc -Append
Get-ADReplicationSiteLink -Filter * | Select-Object Name,Cost,Replicationfrequencyinminutes  | Export-CSV $loc\AD\’Site_Link.csv’ -NoTypeInformation -Encoding Unicode

# GET AD TRUST
Write-Output "`n" ">>>> AD TRUST (Export to AD/AD_Trust.csv) <<<<"  "`n" | Out-File $loc$doc -Append
Get-ADTrust -Filter * | Select-Object Name,Source,Target,Direction | Export-CSV $loc\AD\’AD_Trust.csv’ -NoTypeInformation -Encoding Unicode

# GET NTP
Write-Output "`n" ">>>> NTP (Export to AD/NTP.txt) <<<<" "`n" | Out-File $loc$doc -Append
w32tm /query /computer:$dc_servername /peers | Out-File $loc\AD\’NTP.txt’
				



##### DNS INFO #####

Write-Output  "`n" "`n" "*********** DNS INFO ***********" "`n" "`n" | Out-File $loc$doc -Append

# GET DNS ZONES
Write-Output "`n" ">>>> DNS ZONES (Export to DNS/Zones.csv) <<<<" "`n" | Out-File $loc$doc -Append
Get-DnsServerZone -ComputerName $dc_servername | Select-Object Zonename,ZoneType,IsDsIntegrated | Export-CSV $loc\DNS\’Zones.csv’ -NoTypeInformation -Encoding Unicode

# GET DNS FORWARDERS
Write-Output "`n" ">>>> DNS FORWARDERS (Export to DNS/Forwarders.csv) <<<<" "`n" | Out-File $loc$doc -Append
Get-DnsServerForwarder -ComputerName $dc_servername | Select-Object IPAddress | Export-CSV $loc\DNS\’Forwaders.csv’ -NoTypeInformation -Encoding Unicode

# GET CONDITIONAL FORWARDERS
Write-Output "`n" ">>>> CONDITIONAL FORWARDERS (Export to DNS/Conditional_Forwarders.csv) <<<<" "`n" | Out-File $loc$doc -Append
$list = (Get-ADForest).GlobalCatalogs
$list | ForEach-Object {
	$dcname = $_
	$dcname
	Get-WmiObject -computername $dcname -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone -Filter "ZoneType = 4" | Select-Object -Property @{n='Name';e={$_.ContainerName}}, @{n='DsIntegrated';e={$_.DsIntegrated}}, @{n='MasterServers';e={([string]::Join(',', $_.MasterServers))}} | Format-Table 
} | Out-File $loc\DNS\’Conditional_Forwarders.txt’



##### GPOs INFO #####

Write-Output "`n"  "`n" "************ GPOs INFO ***********" "`n" "`n" | Out-File $loc$doc -Append

# GET GPOs
Write-Output "`n"  ">>>> GPOs (Export to GPOs/Gpos.csv) <<<<" "`n" | Out-File  $loc$doc -Append
Get-GPO -All | Select-Object displayname,gpostatus,creationtime,modificationtime | Export-CSV $loc\GPOs\’Gpos.csv’ -NoTypeInformation -Encoding Unicode

# EXPORT GPOs TO HTML
Write-Output "`n"  ">>>> GPOs IN HTML FORMAT (Folder GPOs/GPOs_HTML) <<<<" "`n" | Out-File $loc$doc -Append
New-Item -ItemType Directory -Force -Path $loc\GPOs\GPOs_HTML
Get-GPO -all | ForEach-Object { Get-GPOReport -GUID $_.id -ReportType HTML -Path "$loc\GPOs\GPOs_HTML\$($_.displayName).html" }

# BACKUP GPOs
Write-Output "`n"  ">>>> BACKUP GPOs (Folder GPOs/GPOs_BK) <<<<" "`n" | Out-File $loc$doc -Append
New-Item -ItemType Directory -Force -Path $loc\GPOs\GPOs_BK
Get-GPO -All | Backup-GPO -Path $loc\GPOs\GPOs_BK

# LINK PATH GPOs
Write-Output "`n"  ">>>> LINK PATH GPOs (Export to GPOs/Linkpathgpos.txt) <<<<" "`n" | Out-File $loc$doc -Append
$GPOs = Get-GPO -All
    "Name,LinkPath,ComputerEnabled,UserEnabled,WmiFilter" | Out-File $loc\GPOs\’Linkpathgpos.txt’ -Append
    $GPOs | ForEach-Object {
        [xml]$Report = $_ | Get-GPOReport -ReportType XML
        $Links = $Report.GPO.LinksTo
        ForEach($Link In $Links){
            $Output = $Report.GPO.Name + "," + $Link.SOMPath + "," + $Report.GPO.Computer.Enabled + "," + $Report.GPO.User.Enabled + "," + $_.WmiFilter.Name
            $Output | Out-File $loc\GPOs\’Linkpathgpos.txt’ -Append
        }
    }

#STOP EVENT LOG
Stop-Transcript