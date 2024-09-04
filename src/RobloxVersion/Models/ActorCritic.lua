--[[

	--------------------------------------------------------------------

	Aqwam's Machine And Deep Learning Library (DataPredict)

	Author: Aqwam Harish Aiman
	
	Email: aqwam.harish.aiman@gmail.com
	
	YouTube: https://www.youtube.com/channel/UCUrwoxv5dufEmbGsxyEUPZw
	
	LinkedIn: https://www.linkedin.com/in/aqwam-harish-aiman/
	
	--------------------------------------------------------------------
		
	By using this library, you agree to comply with our Terms and Conditions in the link below:
	
	https://github.com/AqwamCreates/DataPredict/blob/main/docs/TermsAndConditions.md
	
	--------------------------------------------------------------------
	
	DO NOT REMOVE THIS TEXT!
	
	--------------------------------------------------------------------

--]]

local AqwamMatrixLibrary = require(script.Parent.Parent.AqwamMatrixLibraryLinker.Value)

local ReinforcementLearningActorCriticBaseModel = require(script.Parent.ReinforcementLearningActorCriticBaseModel)

ActorCriticModel = {}

ActorCriticModel.__index = ActorCriticModel

setmetatable(ActorCriticModel, ReinforcementLearningActorCriticBaseModel)

local function calculateProbability(vector)
	
	local meanVector = AqwamMatrixLibrary:horizontalMean(vector)
	
	local standardDeviationVector = AqwamMatrixLibrary:horizontalStandardDeviation(vector)
	
	local zScoreVectorPart1 = AqwamMatrixLibrary:subtract(vector, meanVector)
	
	local zScoreVector = AqwamMatrixLibrary:divide(zScoreVectorPart1, standardDeviationVector)
	
	local zScoreSquaredVector = AqwamMatrixLibrary:power(zScoreVector, 2)
	
	local probabilityVectorPart1 = AqwamMatrixLibrary:multiply(-0.5, zScoreSquaredVector)
	
	local probabilityVectorPart2 = AqwamMatrixLibrary:exponent(probabilityVectorPart1)
	
	local probabilityVectorPart3 = AqwamMatrixLibrary:multiply(standardDeviationVector, math.sqrt(2 * math.pi))
	
	local probabilityVector = AqwamMatrixLibrary:divide(probabilityVectorPart2, probabilityVectorPart3)

	return probabilityVector

end

function ActorCriticModel.new(discountFactor)
	
	local NewActorCriticModel = ReinforcementLearningActorCriticBaseModel.new(discountFactor)
	
	setmetatable(NewActorCriticModel, ActorCriticModel)
	
	local categoricalActionProbabilityValueHistory = {}
	
	local categoricalCriticValueHistory = {}
	
	local categoricalRewardValueHistory = {}
	
	local diagonalGaussianActionProbabilityValueHistory = {}
	
	local diagonalGaussianCriticValueHistory = {}
	
	local diagonalGaussianRewardValueHistory = {}
	
	NewActorCriticModel:setCategoricalUpdateFunction(function(previousFeatureVector, action, rewardValue, currentFeatureVector)
		
		local ActorModel = NewActorCriticModel.ActorModel
		
		local actionVector = ActorModel:predict(previousFeatureVector, true)

		local actionProbabilityVector = calculateProbability(actionVector)

		local criticValue = NewActorCriticModel.CriticModel:predict(previousFeatureVector, true)[1][1]

		local numberOfActions = #actionVector[1]

		local actionIndex = table.find(ActorModel:getClassesList(), action)

		local actionProbability = actionProbabilityVector[1][actionIndex]

		table.insert(categoricalActionProbabilityValueHistory, math.log(actionProbability))

		table.insert(categoricalCriticValueHistory, criticValue)

		table.insert(categoricalRewardValueHistory, rewardValue)
		
	end)
	
	NewActorCriticModel:setCategoricalEpisodeUpdateFunction(function()
		
		local returnValueHistory = {}

		local discountedSum = 0

		local historyLength = #categoricalRewardValueHistory
		
		local discountFactor = NewActorCriticModel.discountFactor

		for h = historyLength, 1, -1 do

			discountedSum = categoricalRewardValueHistory[h] + (discountFactor * discountedSum)

			table.insert(returnValueHistory, 1, discountedSum)

		end

		local sumActorLoss = 0

		local sumCriticLoss = 0

		for h = 1, historyLength, 1 do

			local criticValue = categoricalCriticValueHistory[h]

			local returnValue = returnValueHistory[h]

			local logActionProbability = categoricalActionProbabilityValueHistory[h]
			
			local criticLoss = returnValue - criticValue

			local actorLoss = logActionProbability * criticLoss

			sumCriticLoss = sumCriticLoss + criticLoss
			
			sumActorLoss = sumActorLoss + actorLoss

		end
		
		local ActorModel = NewActorCriticModel.ActorModel

		local CriticModel = NewActorCriticModel.CriticModel
		
		local numberOfFeatures = ActorModel:getTotalNumberOfNeurons(1)

		local numberOfLayers = ActorModel:getNumberOfLayers()

		local numberOfNeuronsAtFinalLayer = ActorModel:getTotalNumberOfNeurons(numberOfLayers)

		local featureVector = AqwamMatrixLibrary:createMatrix(1, numberOfFeatures, 1)
		local sumActorLossVector = AqwamMatrixLibrary:createMatrix(1, numberOfNeuronsAtFinalLayer, -sumActorLoss)

		CriticModel:forwardPropagate(featureVector, true)
		ActorModel:forwardPropagate(featureVector, true)

		CriticModel:backwardPropagate(-sumCriticLoss, true)
		ActorModel:backwardPropagate(sumActorLossVector, true)

		table.clear(categoricalActionProbabilityValueHistory)

		table.clear(categoricalCriticValueHistory)

		table.clear(categoricalRewardValueHistory)
		
	end)
	
	NewActorCriticModel:setCategoricalResetFunction(function()
		
		table.clear(categoricalActionProbabilityValueHistory)

		table.clear(categoricalCriticValueHistory)

		table.clear(categoricalRewardValueHistory)
		
	end)
	
	NewActorCriticModel:setDiagonalGaussianUpdateFunction(function(previousFeatureVector, actionVector, rewardValue, currentFeatureVector)
		
		local zScoreVector, standardDeviationVector = AqwamMatrixLibrary:verticalZScoreNormalization(actionVector)
		
		local squaredZScoreVector = AqwamMatrixLibrary:power(zScoreVector, 2)
		
		local logStandardDeviationVector = AqwamMatrixLibrary:logarithm(standardDeviationVector)
		
		local multipliedLogStandardDeviationVector = AqwamMatrixLibrary:multiply(2, logStandardDeviationVector)
		
		local numberOfActionDimensions = #NewActorCriticModel.ActorModel:getClassesList()
		
		local logLikelihoodPart1 = AqwamMatrixLibrary:sum(multipliedLogStandardDeviationVector)
		
		local logLikelihood = 0.5 * (logLikelihoodPart1 + (numberOfActionDimensions * math.log(2 * math.pi)))

		local criticValue = NewActorCriticModel.CriticModel:predict(previousFeatureVector, true)[1][1]
		
		table.insert(diagonalGaussianActionProbabilityValueHistory, logLikelihood)

		table.insert(diagonalGaussianCriticValueHistory, criticValue)

		table.insert(diagonalGaussianRewardValueHistory, rewardValue)
		
	end)
	
	NewActorCriticModel:setDiagonalGaussianEpisodeUpdateFunction(function()

		local returnValueHistory = {}

		local discountedSum = 0

		local historyLength = #categoricalRewardValueHistory

		local discountFactor = NewActorCriticModel.discountFactor

		for h = historyLength, 1, -1 do

			discountedSum = diagonalGaussianRewardValueHistory[h] + (discountFactor * discountedSum)

			table.insert(returnValueHistory, 1, discountedSum)

		end

		local sumActorLoss = 0

		local sumCriticLoss = 0

		for h = 1, historyLength, 1 do

			local criticValue = diagonalGaussianCriticValueHistory[h]

			local returnValue = returnValueHistory[h]

			local logActionProbability = diagonalGaussianActionProbabilityValueHistory[h]

			local criticLoss = returnValue - criticValue

			local actorLoss = logActionProbability * criticLoss

			sumCriticLoss = sumCriticLoss + criticLoss

			sumActorLoss = sumActorLoss + actorLoss

		end

		local ActorModel = NewActorCriticModel.ActorModel

		local CriticModel = NewActorCriticModel.CriticModel

		local numberOfFeatures = ActorModel:getTotalNumberOfNeurons(1)

		local numberOfLayers = ActorModel:getNumberOfLayers()

		local numberOfNeuronsAtFinalLayer = ActorModel:getTotalNumberOfNeurons(numberOfLayers)

		local featureVector = AqwamMatrixLibrary:createMatrix(1, numberOfFeatures, 1)
		local sumActorLossVector = AqwamMatrixLibrary:createMatrix(1, numberOfNeuronsAtFinalLayer, -sumActorLoss)

		CriticModel:forwardPropagate(featureVector, true)
		ActorModel:forwardPropagate(featureVector, true)

		CriticModel:backwardPropagate(-sumCriticLoss, true)
		ActorModel:backwardPropagate(sumActorLossVector, true)

		table.clear(diagonalGaussianActionProbabilityValueHistory)

		table.clear(diagonalGaussianCriticValueHistory)

		table.clear(diagonalGaussianRewardValueHistory)

	end)
	
	NewActorCriticModel:setDiagonalGaussianResetFunction(function()

		table.clear(diagonalGaussianActionProbabilityValueHistory)

		table.clear(diagonalGaussianCriticValueHistory)

		table.clear(diagonalGaussianRewardValueHistory)

	end)
	
	return NewActorCriticModel
	
end

return ActorCriticModel