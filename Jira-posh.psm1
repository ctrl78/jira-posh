Function ConvertTo-SafeUri($uri) {
  Return [System.Uri]::EscapeDataString($uri)
}

Function Set-JiraApiBase {
Param (
  [Parameter (Mandatory=$True)]
  [string] $jira_api_base
)
      
  # This will take the format http://jira.domain.com/rest/api/2/
  $env:JIRA_API_BASE = $jira_api_base
  Write-Host "Jira Api Base Set:"
  Write-Host $env:JIRA_API_BASE
}


Function Set-JiraHttpProxy {
Param (
  [Parameter (Mandatory=$True)]
  [string] $Httpproxy
)
  $env:JIRA_HTTP_PROXY = $Httpproxy
  Write-Host "Jira proxy Set:"
  Write-Host $env:JIRA_HTTP_PROXY
}


Function Set-JiraCredentials {
Param(
  [Parameter(Mandatory=$True, Position=1)]
  [string]$username,

  [Parameter(Mandatory=$True, Position=2)]
  [System.Security.SecureString]$password
)

  $env:JIRA_CREDENTIALS = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("${username}:$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)))"))
}

Function Invoke-JiraRequest($method, $request, $body, $userAgent='Jira.psm1') {
  ## Fix http://social.technet.microsoft.com/wiki/contents/articles/29863.powershell-rest-api-invoke-restmethod-gotcha.aspx
  $ServicePoint = [System.Net.ServicePointManager]::FindServicePoint(${env:JIRA_API_BASE})
  $ServicePoint.CloseConnectionGroup("")
    If ($env:JIRA_API_BASE -eq $Null) {
      Write-Error "JIRA API Base has not been set, please run ``Set-JiraApiBase'"
  }
  If ($env:JIRA_CREDENTIALS -eq $Null) {
      Write-Error "No JIRA credentials have been set, please run ``Set-JiraCredentials'"
  }
  Write-Debug "Calling $method $env:JIRA_API_BASE$request with AUTH: Basic $env:JIRA_CREDENTIALS $env:JIRA_HTTP_PROXY"
  If ($body -eq $Null) {
      Return Invoke-RestMethod -Uri "${env:JIRA_API_BASE}${request}" -Headers @{"AUTHORIZATION"="Basic $env:JIRA_CREDENTIALS"} -Method $method -ContentType "application/json" -UserAgent $userAgent
  }
  else {
      Return Invoke-RestMethod -Uri "${env:JIRA_API_BASE}${request}" -Headers @{"AUTHORIZATION"="Basic $env:JIRA_CREDENTIALS"} -Method $method -Body $body -ContentType "application/json" -UserAgent $userAgent
  }
}

# Begin Get Functions
Function Get-JiraGroup($group) {
  Return Invoke-JiraRequest GET "group?groupname=$(ConvertTo-SafeUri $group)&expand"
}

Function Get-JiraHistory($issue) {
  Return Invoke-JiraRequest GET "issue/$(ConvertTo-SafeUri $issue)?expand=changelog"
}

Function Get-JiraIssue($issue) {
  Return Invoke-JiraRequest GET "issue/$(ConvertTo-SafeUri $issue)"
}


Function Get-JiraSearchResult($query, $max=50, $start=0) {
  Return Invoke-JiraRequest GET "search?jql=$(ConvertTo-SafeUri $query)&maxResults=$max&startAt=$start"
}

Function Get-JiraProjectList {
  # Returns All Projects on a Jira Server
  Return Invoke-JiraRequest GET "project"
}

Function Get-JiraProject($project) {
  # Returns a Particular Project
  Return Invoke-JiraRequest GET "project/$(ConvertTo-SafeUri $project)"
}

Function Get-JiraProjectRole($project, $role) {
  # Returns Users and Groups in a Role in a Jira Project (10000 - Users; 10002 - Administrators; 10001 - Developers)
  Return Invoke-JiraRequest GET "project/$(ConvertTo-SafeUri $project)/role/$(ConvertTo-SafeUri $role)"
}
# End Get Functions

# Begin Start Functions
Function Start-JiraBackgroundReIndex {
  Return Invoke-JiraRequest POST "reindex"
}
# End Start Functions

# Begin Add Functions
Function Add-JiraGrouptoProject($project, $role, $json) {
  # $json should be valid json like: 
  # { "user" : ["admin"] }  
  # or
  # { "group" : ["jira-developers"] }
  Return Invoke-JiraRequest POST "project/$(ConvertTo-SafeUri $project)/role/$(ConvertTo-SafeUri $role)" $json
}

Function add-JiraIssue {
param (
  [Parameter(Mandatory = $true,Position = 0)]
  [string] $Projectname,
  [Parameter(Mandatory = $true,Position = 1)]
  [string] $Summary,
  [Parameter(Mandatory = $true,Position = 2)]
  [string] $Description,
  [Parameter(Mandatory = $true,Position = 3)]
  [string] $issuetype,
  [Parameter(Mandatory = $true,Position = 4)]
  [string] $assignee,
  [Parameter(Mandatory = $true,Position = 5)]
  [string] $userAgent='Jira.psm1'
)

  $res=Invoke-JiraRequest GET "project/$(ConvertTo-SafeUri $projectname)"
  $projectid=$res.key

  $fields = New-Object -TypeName PSObject -Property ([ordered]@{
  "project"=@{key ="$projectid";}
  "summary"=$Summary;
  "description"=$Description;
  "issuetype"=@{name=$issuetype;}
  "assignee"=@{name=$assignee;}
  })

  $json = New-Object -TypeName PSObject -Property (@{"fields"=$fields}) | ConvertTo-Json
  Write-verbose "Created JSON object:`n$json"

  $jiraissue=Invoke-JiraRequest POST "issue" $json $userAgent
  Return $jiraissue
}

Function Add-JiraComment($issue, $comment) {

  $fields = New-Object -TypeName PSObject -Property ([ordered]@{
  "comments"="";
  "body"="$comment";}
  )

 $body = ('{"body": "'+$comment+'"}')
  $jiracomment=Invoke-JiraRequest POST "issue/$(ConvertTo-SafeUri $issue)/comment" $body
  Return $jiracomment.body
}

Function Add-JiraWatchers {
param (
  [Parameter(Mandatory = $true)][String]$issue,
  [Parameter(Mandatory = $true)][String[]]$jiraWatchers
)
  try {
    foreach ($jiraUser in $jiraWatchers) {
      $jiraUser = '"'+$jiraUser+'"'
      $response=Invoke-JiraRequest POST "issue/$(ConvertTo-SafeUri $issue)/watchers" $jiraUser
      start-sleep -seconds 1
    }
    return $response
  }
  catch {
    write-host $_.Exception.Message
    return $false
  }
}

# End Add Functions

function Update-JiraTicketStatus {
<#
.SYNOPSIS
 Update Jira Ticket Status
.DESCRIPTION
 Update Jira Ticket Status using transition ID or name
.PARAMETER <TicketKey>
 Jira Ticket Key
.PARAMETER <TicketNewStatus>
 Jira Ticket Status
 New Ticket Status should be one of the next available status
 in the ticket workflow
.PARAMETER <TransitionID>
 Jira Ticket Transition ID
 Transition ID should be contained in the available transition list
 provided by Invoke-JiraRequest GET "issue/<TICKET-KEY>/transitions
.EXAMPLE
 Update-JiraTicketStatus -TicketKey KAN-10062 -TicketNewStatus Close
.EXAMPLE
 Update-JiraTicketStatus -TicketKey KAN-10062 -TransitionID 201
#>
  param(
    [Parameter(Mandatory = $True)]
    [string]$TicketKey,
    [string]$TicketNewStatus,
    [string]$TransitionID
  )
  
  if (-not($TicketNewStatus) -and -not($TransitionID)) {
    return $false
  }
  if (-not($TransitionID)) {
    try {
      $transition = Invoke-JiraRequest GET "issue/$TicketKey/transitions"
      $TransitionID = ($transition.transitions | where { $_.name -eq $TicketNewStatus } | select id).id
    }
    catch {
      Write-Host "Error: could not get transition ID. $($_.Exception.Message)"
      return $false
    }
  }
  try {
    Invoke-JiraRequest POST "issue/$TicketKey/transitions" "{`"transition`": {`"id`": `"$TransitionID`"}}"
  }
  catch {
    Write-Host "Error: could not update ticket transition. $($_.Exception.Message)"
    return $false
  }
  return $true
}

Export-ModuleMember -Function Set-JiraApiBase,
                              Set-JiraCredentials,
                              Set-JiraHttpProxy,
                              ConvertTo-SafeUri,
                              Invoke-JiraRequest,
                              Add-JiraGrouptoProject,
                              Get-JiraGroup,
                              Get-JiraProjectList,
                              Get-JiraProject,
                              Get-JiraProjectRole,
                              Get-JiraIssue,
                              Get-JiraHistory,
                              Get-JiraSearchResult,
                              Add-JiraIssue,
                              Add-JiraComment,
                              Start-JiraBackgroundReIndex,
                              Add-JiraWatchers,
                              Update-JiraTicketStatus
