flyway init "-init.projectName=foo" "-init.databaseType=oracle" 

flyway diff model "-diff.source=dev" "-diff.target=empty" "-environments.dev.url=jdbc:oracle:thin:@//az-usc1-dv-organization-sc1.gcve-np.autozone.com:19100/organization.gcve-np.autozone.com" "-environments.dev.user=system" "-environments.dev.password=foo" "-environments.dev.schemas=FOO,BAR" 

flyway diff generate "-diff.source=schemaModel" "-diff.target=empty" "-generate.types=baseline" "-generate.version=000__baseline"  "-schemaModelSchemas=FOO,BAR"