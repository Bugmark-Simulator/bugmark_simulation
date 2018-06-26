module UserGenerationSettings
	##### Modify you input for users to be generated###
	#Insert number of users to create
	$numberofusers = 5    

	# Select type of user to create
	$usertype="funder"
	#usertype="worker"
	#usertype="admin"

	# Select the balance to assign
	$userbalance = 100

	#Skills available
	$skills = ["java","ruby","python","HTML","SQL","c","GO","R"]

	# Select number of skills to assign
	$numberofskills = 3

	# Select user treatment
	$usertreatment = "no"
	#usertreatment = "market"
	#usertreatment = "health"
	#usertreatment = "both"
end