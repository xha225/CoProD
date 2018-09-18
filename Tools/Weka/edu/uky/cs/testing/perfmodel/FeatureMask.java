package edu.uky.cs.testing.perfmodel;

public class FeatureMask {
private int classColumn;
private int[] columnsToBeRemoved;

public int SetClassColumn(int val){
	classColumn = val;
	return classColumn;
}

public int[] SetColumnsToBeRemoved(int[] arr){
	columnsToBeRemoved = arr;
	return columnsToBeRemoved;
}

public int GetClassColumn(){
	return classColumn;
}

public int[] GetColumnsToBeRemoved(){
	return columnsToBeRemoved;
}
}
