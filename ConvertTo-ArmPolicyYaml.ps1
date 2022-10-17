$policy = Get-AzFirewallPolicy -ResourceGroupName "rg" -name "existing-policy"
$outputPath = ".\Rules"

#region Helper functions
function Expand-ParametersInArrayProperty {
    param(
        $Items,
        $Parameters,
        [bool]$ForceEmptyArrayResult = $true,
        [bool]$ForceSingleItemArrayResult = $true
    )

    $output = @()
    foreach($item in $Items) {
        if($item -match "\[parameters\('([^']+)'\)\]") {
            $output += $Parameters.$($Matches[1]).defaultValue
        } else {
            $output += $item
        }
    }

    if(($output.Length -eq 0 -and $ForceEmptyArrayResult) -or ($output.Length -eq 1 -and $ForceSingleItemArrayResult)) {
        Write-Output -NoEnumerate $output # force to return array (even with single item records)
    } else {
        Write-Output $output
    }
}
#endregion

#region Convert Policy
$temp = New-TemporaryFile 
Export-AzResourceGroup -ResourceGroupName $policy.ResourceGroupName -Resource $policy.Id -Path $temp.FullName -IncludeParameterDefaultValue
$json = Get-Content "$($temp.FullName).json" | ConvertFrom-Json -Depth 10
Remove-Item -Path "$($temp.FullName).json"

$rcgs = $json.resources | Where-Object type -eq "Microsoft.Network/firewallPolicies/ruleCollectionGroups"
Write-Output "Rule Collections Groups [$($rcgs.Length)]:"
foreach($rcg in $rcgs) {
    $parts = ($rcg.name -split "./")
    $name = $parts[1].Substring(0, $parts[1].Length - 3)

    Write-Output " * $($name) [$($rcg.properties.ruleCollections.Count) rule collections]"

    $path = Join-Path $outputPath $name
    if(-not(Test-Path -Path $path)) {
        $rcgDirectory = New-Item -ItemType Directory -Path $path
    } else {
        $rcgDirectory = Get-Item -Path $path
    }

    $metadata = @"
name: $name
priority: $($rcg.properties.priority)
"@
    Set-Content -Path (Join-Path $rcgDirectory.FullName "collection.yaml") -Value $metadata

    $ruleCollections = $rcg.properties.ruleCollections
    foreach($ruleCollection in $ruleCollections) {
        $content = [PSCustomObject]@{
            name = $ruleCollection.name
            priority = $ruleCollection.priority
            action = $ruleCollection.action.type
            rules = @()
        }

        Write-Output "   + $($ruleCollection.name) with $($ruleCollection.rules.Length) rules"
        Write-Output "     Rules Count: $($ruleCollection.rules.Length)"

        $collectionType = "?"
        if($ruleCollection.rules.Length -eq 0) {
            Write-Output "     [!] $($ruleCollection.name) as does not contain any rule -> guessing type from name"
            if($ruleCollection.name -match "Network-Collection$") {
                $collectionType = "NetworkRule"
            }
            if($ruleCollection.name -match "Application-Collection$") {
                $collectionType = "ApplicationRule"
            }
            Write-Warning "Skipping empty rule collection $($ruleCollection.name) from export as Terraform does not support this scenario."
            continue # terraform does not support empty rule collection ()
            <#
            Error: Insufficient rule blocks
            │ At least 1 "rule" blocks are required.
            #>
        } else {
            $groups = $ruleCollection.rules | Group-Object -Property ruleType
            if($groups.Length -gt 1) {
                throw "Unsupported scenario with multiple kinds of items in one rule collection"
            }
            $group = $groups | Select-Object -First 1
            $collectionType = $group.Name
        }
        
        Write-Output "     Type: $($collectionType)"

        $fileNamePrefix = "?"
        switch($collectionType) 
        {
            "NetworkRule" { $fileNamePrefix = "network" }
            "ApplicationRule" { $fileNamePrefix = "application" }
            default { 
                Write-Host $group.Name
                throw "Unsupported firewall rule type $($group.Name)" 
            }
        }
        $fileName = "$($fileNamePrefix)_$($ruleCollection.name).yaml"

        if($ruleCollection.rules.Length -gt 0) {
            foreach($rule in $ruleCollection.rules) {
                if($collectionType -eq "NetworkRule") {
                    $ruleData = @{
                        name = $rule.name
                        protocols = Expand-ParametersInArrayProperty -Items $rule.ipProtocols -Parameters $json.parameters -ForceSingleItemArrayResult $false
                        destination_ports = Expand-ParametersInArrayProperty -Items $rule.destinationPorts -Parameters $json.parameters -ForceSingleItemArrayResult $false
                    }
                    if($rule.sourceAddresses.Length -gt 0) {
                        $ruleData["source_addresses"] = Expand-ParametersInArrayProperty -Items $rule.sourceAddresses -Parameters $json.parameters -ForceSingleItemArrayResult $false
                    }
                    if($rule.destinationAddresses.Length -gt 0) {
                        $ruleData["destination_addresses"] = Expand-ParametersInArrayProperty -Items $rule.destinationAddresses -Parameters $json.parameters -ForceSingleItemArrayResult $false
                    }
                    if($rule.destinationFqdns.Length -gt 0) {
                        $ruleData["destination_fqdns"] = Expand-ParametersInArrayProperty -Items $rule.destinationFqdns -Parameters $json.parameters -ForceSingleItemArrayResult $false
                    }
                    if($rule.destinationIpGroups.Length -gt 0) {
                        $ruleData["destination_ip_groups"] = Expand-ParametersInArrayProperty -Items $rule.destinationIpGroups -Parameters $json.parameters -ForceSingleItemArrayResult $false
                    }
                    if($rule.sourceIpGroups.Length -gt 0) {
                        $ruleData["source_ip_groups"] = Expand-ParametersInArrayProperty -Items $rule.sourceIpGroups -Parameters $json.parameters -ForceSingleItemArrayResult $false
                    }

                    $content.rules += [PSCustomObject]$ruleData
                }
                if($collectionType -eq "ApplicationRule") {
                    $ruleData = @{
                        name = $rule.name
                        protocols = @()
                    }
                    if($rule.targetFqdns.Length -gt 0) {
                        $ruleData["destination_fqdns"] = Expand-ParametersInArrayProperty -Items $rule.targetFqdns -Parameters $json.parameters -ForceSingleItemArrayResult $false
                    }
                    if($rule.fqdnTags.Length -gt 0) {
                        $ruleData["destination_fqdn_tags"] = Expand-ParametersInArrayProperty -Items $rule.fqdnTags -Parameters $json.parameters -ForceSingleItemArrayResult $false
                    }
                    if($rule.sourceAddresses.Length -gt 0) {
                        $ruleData["source_addresses"] = Expand-ParametersInArrayProperty -Items $rule.sourceAddresses -Parameters $json.parameters -ForceSingleItemArrayResult $false
                    }
                    if($rule.sourceIpGroups.Length -gt 0) {
                        $ruleData["source_ip_groups"] = Expand-ParametersInArrayProperty -Items $rule.sourceIpGroups -Parameters $json.parameters -ForceSingleItemArrayResult $false
                    }
                    foreach($protocol in $rule.protocols) {
                        $ruleData.protocols += [PSCustomObject]@{
                            type = $protocol.protocolType
                            port = $protocol.port
                        }
                    }
                    $content.rules += [PSCustomObject]$ruleData
                }
            }
        }

        $yaml = $content | ConvertTo-Yaml
        Set-Content -Value $yaml -Path (Join-Path $rcgDirectory.FullName $fileName)
    }
}
#endregion

# generate folder names to paste in terraform definition
Get-ChildItem $outputPath | Select-Object -ExpandProperty Name | ForEach-Object { "`"$($_)`"," } | scb
