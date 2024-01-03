param ($deploymentTargetsList, $baselineVersion, $flywayLicenseKey, $workingDirectory)

write-host "deploymentTargetsList: $deploymentTargetsList"

Import-csv -path $deploymentTargetsList |
    Foreach-object {

			$currentJDBC = $_.JDBCString
            $deployment = "flyway migrate -outOfOrder='true' -baselineOnMigrate='true' -errorOverrides='S0001:0:I'- -baselineVersion=" + $baselineVersion + " -licenseKey=" +  $flywayLicenseKey + " -configFiles=" + $workingDirectory + "\flyway.conf" + " -locations=filesystem:" + $workingDirectory + '\migrations' + " -url='" + $currentJDBC + "'" 
			write-host "flywayCommand:" + $deployment
            write-host "deploying to: $currentJDBC"
            Invoke-Expression $deployment
    }
