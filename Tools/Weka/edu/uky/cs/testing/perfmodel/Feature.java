package edu.uky.cs.testing.perfmodel;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

import weka.classifiers.Classifier;
import weka.classifiers.Evaluation;
import weka.classifiers.functions.LinearRegression;

public class Feature {

	private int RankScore;
	private double curErrRate;
	// Linear Regression
	public static final String LR = "LR";
	// Support Vector Machine Regression
	public static final String SMO = "SMO";
	// Multi-Perceptron
	public static final String MP = "MP";
	// Constant
	public static final String CONST = "CONST";

	// Evaluation for each individual classifier of the same feature
	private HashMap<String, Evaluation> evals;
	// Classifier for each model tried on the feature
	private HashMap<String, Classifier> models;

	public Feature() {
		evals = new HashMap<String, Evaluation>();
		models = new HashMap<String, Classifier>();
	}

	public int GetRankScore() {
		return RankScore;
	}

	public void AddModels(String name, Classifier model) {
		try {
			models.put(name, model);

		} catch (Exception ex) {
			System.err.println(ex.toString());
		}
	}

	public Classifier GetModel(String name) {
		return models.get(name);
	}

	public void AddEvalItem(String name, Evaluation eval) {
		evals.put(name, eval);
	}

	public Evaluation GetEvalByName(String name) {
		return evals.get(name);
	}

	// Select from all available models based on MSR error
	public String GetSelectedModel() {
		// Init min error to a relatively larger value
		
		curErrRate=100;
		
		String selectedModel = "notSelected";
		String curModel = "notSelected";
		
		Iterator<?> it = evals.entrySet().iterator();

		// Loop through all models and compare the error rate
		while (it.hasNext()) {
			@SuppressWarnings("unchecked")
			Map.Entry<String, Evaluation> entry = (Map.Entry<String, Evaluation>) it
					.next();
			curModel = entry.getKey();
			if (entry.getValue().errorRate() <= curErrRate) {
				curErrRate = entry.getValue().errorRate();
				selectedModel = curModel;
			}
		} // while

		if (selectedModel == Feature.LR) {
			if (IsConstModel((LinearRegression) models.get(Feature.LR))) {
				return Feature.CONST;
			} // if IsConstModel
		} // if
		return selectedModel;
	}
	
	public double GetModelErrRate() {
		return curErrRate;
	}// GetModelErrRate

	public boolean IsConstModel(LinearRegression model) {
		// Get co-efficients
		double coefficient = model.coefficients()[0];
		// for (double coefficient : model.coefficients()){
		// if co-efficient is zero, then the feature has no impact
		if (coefficient > -0.001 && coefficient < 0.001) {
			System.err.println("Co-efficient: " + coefficient );
			double errRate = evals.get(Feature.LR).errorRate();
			if (errRate == 0){
			return true;
			}
		} 
			
		return false;
	} // IsConstModel

} // class Feature
