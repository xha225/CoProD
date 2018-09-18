// V1.4
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include "pin.H"
#include <map>
#include <unordered_set>
#include <unistd.h>
#include <syscall.h>
#include <ctime>
#include <time.h>
#include <stdint.h>	// for uint64 definition 
#include <fstream>
#include <stack>
using namespace std;

#define P_MUTEX_LOCK "pthread_mutex_lock"
const bool VERBOSE = false; // Print extra logging
const bool trackPthread = false; // track pthread
const string DATA_DIR = "/RawProfileData/";
const string LOOP_CNT_DATA = DATA_DIR + "loopInsCount.data";
const string ROUTINE_DATA = DATA_DIR + "rtnCall.data";
const string SYS_CALL_DATA =  DATA_DIR + "systemCall.data";
const string PTHREAD_CALL_DATA = DATA_DIR + "pthread.data";

ofstream loopCountData;
ofstream loopToExeTime; // Used to convert execution time to loop count
ofstream routineTrace;
ofstream routineData;
ofstream rtnCallData; // Number of time a routine gets called
ofstream pthreadCallData;

//TODO see if I can convert sysCallData into ofstream as well
FILE * sysCallData;

static bool isLcdExist = false; // Control whether to write header to loopCountData
static bool isRcdExist = false; // Routine call data
static bool isScdExist = false; // System call data
static bool isPcdExist = false; // pthread call data

// Trace file control
bool enableRtnTrace = false;
bool enableRtnCall = false;
bool enableRoutineData = false;
bool enableLoopToTime = false;

static struct timespec sysStart;
static int stackCounter = 0;

typedef struct ForLoop{
	// Loop identifier, instruction virtual address as seen in objdump 
	ADDRINT id;
	// Number of iteration
	UINT64 numOfIter;
	// Instruction executed
	UINT64 numOfIns;
	// Number of instructions executed since last iteration
	UINT64 numOfInsSinceLast;
	string sourceInfo;
	string assembly;
	UINT64 operand;
	struct timespec start, end;
	uint64_t secElapsed;
	uint64_t nanoElapsed;
} ForLoop;

typedef struct SysIns{
// System call address, used as ID
ADDRINT id;
// System call number
UINT32 sysCallNum;
UINT64 numOfIns;
UINT64 callCounter;
// In millisecond
UINT64 exeTime; 
//uint64_t exeTime; 
} SysIns;

// Use function pointer as the key to 
// track the number of branch instructions in a routine
typedef struct FpInsCounter{
ADDRINT fp; // frame/function pointer
UINT64 start;
UINT64 end;
} FpInsCounter;

typedef struct RoutineStats{
string name;
map<ADDRINT,UINT64> mapFpInsStart; 
UINT64 numOfIns;
UINT64 numOfCalls;
} RoutineStats;

static unordered_set<ADDRINT> loopStack;
static unordered_set<SysIns*> sysCallSet;
static map<ADDRINT, ForLoop*> ForLoopMap;
static map<ADDRINT, SysIns*> mapAddrSysIns;
static stack<SysIns*> sysInsStack;
static map<string, RoutineStats*> rtnInfoMap;
static stack<struct timespec> stackRoutineStartClock;
static map<string, struct timespec> mapRoutineStartClock;
// The running count of instructions is kept here
// make it static to help the compiler optimize docount
static UINT64 icount = 0;
//static UINT64 sysInsCount = 0;

// TODO: change to inline function
int GetMsFromS(int sec){
	return sec * 1000;
}

float GetMsFromNanoS(long nanoS){
	return (float)nanoS/1000000;
}

void PrintDash(int numOfDash, ofstream & out){
	out << dec << "-" << numOfDash << "-";
}

KNOB<string> KnobOutputFile(KNOB_MODE_WRITEONCE, "pintool",
		"o", "loopInsCount.data", "specify output file name");

KNOB<string> KnobOutputDir(KNOB_MODE_WRITEONCE, "pintool",
		"outDir", "./", "specify output directory name");

KNOB<string> KnobConfigName(KNOB_MODE_WRITEONCE, "pintool",
		"ConfigName", "noConfigName", "specify configuration name");

KNOB<string> KnobConfigVal(KNOB_MODE_WRITEONCE, "pintool",
		"ConfigVal", "noConfigVal", "specify configuration name");

KNOB<UINT32> KnobTestId(KNOB_MODE_WRITEONCE, "pintool",
		"testId", "1", "specify test id");

KNOB<string> KnobSourceFilter(KNOB_MODE_WRITEONCE, "pintool",
		"SourceFilter", "", "specify source path filter");

// Print syscall number and arguments
VOID SysBefore(ADDRINT ip, ADDRINT num, ADDRINT arg0, ADDRINT arg1, ADDRINT arg2, ADDRINT arg3, ADDRINT arg4, ADDRINT arg5)
{
	//fprintf(sysCallData,"SysBefore:%lx\n",(unsigned long)ip);
	//fflush(sysCallData);
	clock_gettime(CLOCK_MONOTONIC, &sysStart);
#if defined(TARGET_LINUX) && defined(TARGET_IA32) 
	// On ia32 Linux, there are only 5 registers for passing system call arguments, 
	// but mmap needs 6. For mmap on ia32, the first argument to the system call 
	// is a pointer to an array of the 6 arguments
	if (num == SYS_mmap)
	{
		ADDRINT * mmapArgs = reinterpret_cast<ADDRINT *>(arg0);
		arg0 = mmapArgs[0];
		arg1 = mmapArgs[1];
		arg2 = mmapArgs[2];
		arg3 = mmapArgs[3];
		arg4 = mmapArgs[4];
		arg5 = mmapArgs[5];
	}
#endif
	/*
		 systemCallLog << hex 
		 << (unsigned long)ip << ": (" << dec << (long)num << ")\t" << hex
		 << (unsigned long)arg0 << "\t" << (unsigned long)arg1 << "\t"
		 << (unsigned long)arg2 << "\t" <<	(unsigned long)arg3 << "\t"
		 << (unsigned long)arg4 << "\t" << (unsigned long)arg5 << endl;
	*/

	// Prepare system call 
		SysIns *sysIns = new SysIns();
		sysIns->id = ip;
		sysIns->sysCallNum = (UINT32)num;
		sysIns->callCounter = 1;
		sysIns->numOfIns=0;
		sysIns->exeTime=0;

		sysInsStack.push(sysIns);
	/*	fprintf(sysCallData,"0x%lx,%u,%ld,",
			(unsigned long)ip,
			KnobTestId.Value(),
			(long)num);
	 */
}

// rtn: the return value of the system call
VOID SysAfter(ADDRINT rtn)
{ 
	//fprintf(sysCallData,"SysAfter:%lx\n",(unsigned long)rtn);
	struct timespec sysEnd;
	clock_gettime(CLOCK_MONOTONIC, &sysEnd);
	
	if(!sysInsStack.empty()){
		SysIns *sysIns = sysInsStack.top();
		sysInsStack.pop();
		//fprintf(sysCallData,"Pop instruction!");
		long secDiff = sysEnd.tv_sec - sysStart.tv_sec;
		long nanoDiff = sysEnd.tv_nsec - sysStart.tv_nsec;
		long exeTime = (float)GetMsFromS(secDiff) + GetMsFromNanoS(nanoDiff);
		sysIns->exeTime = exeTime;
    // Add sys call to set
		sysCallSet.insert(sysIns);
	}
	// fprintf(sysCallData,"--%ld,%ld",secDiff,nanoDiff);
	fflush(sysCallData);
}

VOID SyscallExit(THREADID threadIndex, CONTEXT *ctxt, SYSCALL_STANDARD std, VOID *v)
{
	SysAfter(PIN_GetSyscallReturn(ctxt, std));
}

VOID SyscallEntry(THREADID threadIndex, CONTEXT *ctxt, SYSCALL_STANDARD std, VOID *v){
	SysBefore(PIN_GetContextReg(ctxt, REG_INST_PTR),
			PIN_GetSyscallNumber(ctxt, std),
			PIN_GetSyscallArgument(ctxt, std, 0),
			PIN_GetSyscallArgument(ctxt, std, 1),
			PIN_GetSyscallArgument(ctxt, std, 2),
			PIN_GetSyscallArgument(ctxt, std, 3),
			PIN_GetSyscallArgument(ctxt, std, 4),
			PIN_GetSyscallArgument(ctxt, std, 5));
}

VOID ForkCallBack(THREADID threadid, const CONTEXT *ctxt, VOID *v){
}

BOOL FollowChild(CHILD_PROCESS childProcess, VOID * userData)
{
	cout << "before child: " << getpid()<<" parent ID " << getppid() << endl;
	return TRUE;
}

/* name: name of the function
 * size: 	 

 */
VOID MutexLockBefore(CHAR * name, ADDRINT *addr,THREADID threadid, UINT64 tsc){
	pthreadCallData << name << "(" << *addr << "),threadid: " << threadid << ",timestamp: " << tsc << endl;
} // MutexLockBefore

VOID MutexLockAfter(ADDRINT *addr,THREADID threadid, UINT64 tsc){
	pthreadCallData << "(" << *addr << "),threadid: " << threadid << ",timestamp: " << tsc << endl;
} // MutexLockAfter

VOID ImageLoad(IMG img, VOID *v){
	// !!!TODO!!!
	// Look up lock_perf-36366.cpp from Dr. Yu, and add PIN_GetLock
	// https://software.intel.com/sites/landingpage/pintool/docs/53271/Pin/html/index.html#MallocMT
	// !!!TODO!!!

	SYM sym= IMG_RegsymHead(img);
	if(VERBOSE){
		cout << "!!!" << PIN_UndecorateSymbolName(SYM_Name(sym),UNDECORATION_COMPLETE) << endl; 
	}

	// Instrument on pthread_mutex_lock routine
	if(trackPthread){
		RTN mutexLockRtn = RTN_FindByName(img, P_MUTEX_LOCK);
		if (RTN_Valid(mutexLockRtn)){
			RTN_Open(mutexLockRtn);

			// Instrument print the input argument value and the return value.
			RTN_InsertCall(mutexLockRtn, IPOINT_BEFORE, (AFUNPTR)MutexLockBefore,
					IARG_ADDRINT, P_MUTEX_LOCK,
					IARG_FUNCARG_ENTRYPOINT_REFERENCE, 0,
					IARG_THREAD_ID,
					IARG_TSC,
					IARG_END);

			RTN_InsertCall(mutexLockRtn, IPOINT_AFTER, (AFUNPTR)MutexLockAfter,
					IARG_FUNCRET_EXITPOINT_REFERENCE, 
					IARG_THREAD_ID,
					IARG_TSC,
					IARG_END);

			RTN_Close(mutexLockRtn);
		}
	}
}

VOID docount(VOID *v){
	icount++;
}

VOID CountSystemCall(ADDRINT addr, VOID *v){
	//systemCallLog << hex << addr <<": "<< dec << *static_cast<string*>(v) << ": " << sysInsCount++ << endl;
}

// This function is called before every instruction is executed
VOID InsAnalysis() {
}

VOID PrintRtnHead(ADDRINT src, const CONTEXT * ctxt){
	PIN_LockClient();
	string routineName = PIN_UndecorateSymbolName(RTN_FindNameByAddress(src),UNDECORATION_NAME_ONLY);
	stackCounter ++;
	ADDRINT fp;
	// Get frame pointer address
	PIN_GetContextRegval(ctxt, REG_EBP, reinterpret_cast<UINT8*>(&fp));
	// Frame pointer used as map id by appending function name
	stringstream stream;
	stream << hex << fp;
	string fpAddr(stream.str());
	string funFpName=routineName+"_"+fpAddr;

	map<string, struct RoutineStats *>::iterator riIter =  rtnInfoMap.find(routineName);
	if(riIter != rtnInfoMap.end()){
		// Update count
		riIter->second->numOfCalls++;
		// Record the start instruction count
		map<ADDRINT,UINT64>::iterator it = riIter->second->mapFpInsStart.find(fp) ;
		if(it == riIter->second->mapFpInsStart.end()){
			riIter->second->mapFpInsStart.insert(make_pair(fp,icount));
		}
	}else{
		// Add routine to the map
		RoutineStats *ri = new RoutineStats();
		// Init
		ri->name=routineName;
		ri->numOfIns=0;
		ri->numOfCalls=1;
		ri->mapFpInsStart.insert(make_pair(fp,icount));

		rtnInfoMap.insert(make_pair(routineName,ri));
	}

	struct timespec startClock;
	clock_gettime(CLOCK_MONOTONIC, &startClock);	// mark the routine start time

	map<string, struct timespec>::iterator it = mapRoutineStartClock.find(funFpName);
	if (it != mapRoutineStartClock.end()){ 
		if(enableRtnTrace)  routineTrace << "!! The impossible has happend. New framepointer is not created??" << endl;
	}else{
		// Add frame pointer to the map
		// TOOD: check startClock, should it not be a struct pointer so that the content does not lost outside the function?
		mapRoutineStartClock.insert(make_pair(funFpName, startClock));
	}

	PrintDash(stackCounter,routineTrace);
	if(enableRtnTrace) routineTrace << ", " << funFpName << ", " << routineName << ", [start]" 
		<< ", " << REG_StringShort(REG_EBP) << ": 0x" << hex << fp << endl;

	stackRoutineStartClock.push(startClock);

	PIN_UnlockClient();
}

VOID PrintRtnReturn(ADDRINT src, const CONTEXT * ctxt){
	PIN_LockClient();

	string routineName=PIN_UndecorateSymbolName(RTN_FindNameByAddress(src),UNDECORATION_NAME_ONLY);
	struct timespec start,fpStart,end;
	clock_gettime(CLOCK_MONOTONIC, &end);	// mark the end time
	ADDRINT fp;
	// Get frame pointer address
	PIN_GetContextRegval(ctxt, REG_EBP, reinterpret_cast<UINT8*>(&fp));

	// Frame pointer used as map id by appending function name
	stringstream stream;
	stream << hex << fp;
	string fpAddr(stream.str());
	string funFpName = routineName+"_"+fpAddr;
	float rtnExeTime = 0; 

	// Calculate instruction count difference and update the total instruction of the routine
	map<string, struct RoutineStats *>::iterator riIter =  rtnInfoMap.find(routineName);
	if(riIter != rtnInfoMap.end()){
		// Record the start instruction count
		map<ADDRINT,UINT64>::iterator iterFpInsStart = riIter->second->mapFpInsStart.find(fp) ;
		if(iterFpInsStart != riIter->second->mapFpInsStart.end()){
			// Udate instruction count in the routine
			riIter->second->numOfIns += icount - iterFpInsStart->second;
			// Remove the function pointer from map to make space for other function
			// stored at the same function pointer location
			riIter->second->mapFpInsStart.erase(iterFpInsStart);
		}
	}

	// Execution time
	map<string, struct timespec>::iterator it = mapRoutineStartClock.find(funFpName);
	if(it != mapRoutineStartClock.end()){
		fpStart = it->second;
		rtnExeTime = (float)GetMsFromS(end.tv_sec - fpStart.tv_sec) + GetMsFromNanoS(end.tv_nsec-fpStart.tv_nsec); 
		// Write to routine data
		if(enableRoutineData){
			routineData << routineName << ", " << dec << KnobTestId.Value() << ", " << rtnExeTime << endl;
		}
		// Remove key-value pair
		mapRoutineStartClock.erase(it);	
		if(enableRtnTrace) routineTrace << "\nFrom frame pointer clock: " << dec 
			<< rtnExeTime  << endl; 
	}else{
		if(enableRtnTrace) routineTrace << "!!Returned without being put in to frame pointer first??" << endl;
	} 

	// The stack method is left here to compare with the frame pointer method
	// Obvious, the stack method is off
	if(!stackRoutineStartClock.empty()){
		start = stackRoutineStartClock.top();
		PrintDash(stackCounter,routineTrace);
		stackCounter --;
		if(enableRtnTrace) routineTrace << PIN_UndecorateSymbolName(RTN_FindNameByAddress(src),UNDECORATION_NAME_ONLY)
			<< ", [return]" << ", " << dec << (end.tv_sec - start.tv_sec)*1000000000 + (end.tv_nsec-start.tv_nsec); 
		stackRoutineStartClock.pop();
	} else{
		if(enableRtnTrace) routineTrace << "[missing start return], " << RTN_FindNameByAddress(src) <<", -1"; 
	}

	if(enableRtnTrace) routineTrace << ", " << REG_StringShort(REG_EBP) << ": 0x" << hex << fp << endl;

	PIN_UnlockClient();

}//PrintRtnReturn

// Pin calls this function every time a new instruction is encountered
VOID Instruction(INS ins, VOID *v)
{
	//if(INS_IsBranch(ins)){
		// Insert a call to docount before every instruction, no arguments are passed
	INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)docount, IARG_END);
	//}
	// TODO delete variable on heap, 
	// the instrumentation does not seem to work with the IN_HasFallThrough instruction
	if(INS_IsSyscall(ins) && INS_HasFallThrough(ins)){
		cout << "Ready to instrument SysBefore and SysAfter" << endl;
		INS_InsertCall(ins, IPOINT_BEFORE, AFUNPTR(SysBefore),
				IARG_INST_PTR, 
				IARG_SYSCALL_NUMBER,
				IARG_SYSARG_VALUE, 0, IARG_SYSARG_VALUE, 1,
				IARG_SYSARG_VALUE, 2, IARG_SYSARG_VALUE, 3,
				IARG_SYSARG_VALUE, 4, IARG_SYSARG_VALUE, 5,
				IARG_END);
		//INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)CountSystemCall, IARG_INST_PTR, IARG_PTR, new string(INS_Mnemonic(ins)), IARG_END);
		// return value only available after
		INS_InsertCall(ins, IPOINT_AFTER, AFUNPTR(SysAfter),
				IARG_INST_PTR, 
				IARG_SYSCALL_NUMBER,
				IARG_END);
	}
}

VOID CloseForLoop(ADDRINT addr, VOID *v){
	PIN_LockClient();
	// Remove loop from stack
	unordered_set<UINT64>::const_iterator it = loopStack.find(addr);
	if (it != loopStack.end() ){
		map<ADDRINT, ForLoop*>::iterator mapIt = ForLoopMap.find(addr);
		if (mapIt != ForLoopMap.end()){
			// TODO: is this a problem when the loop gets executed by multiple procedure?
			// Such that when the multiple processes try to update the loop counter interleavingly
			mapIt->second->numOfInsSinceLast = 0;
			clock_gettime(CLOCK_MONOTONIC, &(mapIt->second->end));	/* mark the end time */
			mapIt->second->secElapsed += mapIt->second->end.tv_sec - mapIt->second->start.tv_sec;  
			mapIt->second->nanoElapsed += mapIt->second->end.tv_nsec - mapIt->second->start.tv_nsec;  
		}
		loopStack.erase(it);
	}
	PIN_UnlockClient();
}

VOID UpdateForLoopCount(ADDRINT addr,const CONTEXT * ctxt, VOID *v){
	PIN_LockClient();
	// TODO: delete later
	map<ADDRINT, ForLoop*>::iterator it = ForLoopMap.find(addr);
	// Get frame pointer address
	/*	ADDRINT fp;
			PIN_GetContextRegval(ctxt, REG_EBP, reinterpret_cast<UINT8*>(&fp));
			ADDRINT sp;
			PIN_GetContextRegval(ctxt, REG_ESP, reinterpret_cast<UINT8*>(&sp));
			cout << "function pointer: " << fp << "stack pointer: " << sp << endl;
	 */
	if (it != ForLoopMap.end()){ // Found loop id
		// If loop is in the stack, update instruction count
		// else, put it in the stack
		if(loopStack.find(addr) == loopStack.end() ){// not in loop stack
			loopStack.insert(addr);
			//cout << "inserted:" << hex << addr << endl;
			// Initialize start clock
			clock_gettime(CLOCK_MONOTONIC, &(it->second->start));	/* mark start time */
		}else{ // Not the first time seen the jump
			//cout << "loop on stack" << hex << addr << endl;
			it->second->numOfIter++;
		}

		if(it->second->numOfInsSinceLast != 0){
			it->second->numOfIns += icount - it->second->numOfInsSinceLast;		
		} 
		it->second->numOfInsSinceLast = icount;
		//cout << "Analysis: " << it->second->id << ": " << it->second->numOfInsSinceLast << endl; 
	} // if in FooLoopMap
	PIN_UnlockClient();
} // UpdateForLoopCount

// Pin calls this function every time a new basic block is encountered
// It inserts a call to docount
VOID Trace(TRACE trace, VOID *v)
{
	bool bPrintFileName = true;

	string filename; 
	INT32 line = 0;     // This will hold the line number within the file.

	// Visit every basic block  in the trace
	for (BBL bbl = TRACE_BblHead(trace); BBL_Valid(bbl); bbl = BBL_Next(bbl))
	{
		// Insert a call to docount before every bbl, passing the number of instructions
		for(INS ins= BBL_InsHead(bbl); INS_Valid(ins); ins=INS_Next(ins)){
			PIN_GetSourceLocation(INS_Address(ins), NULL, &line, &filename);
			// Filter out out of scope instructions
			if (filename.empty()){
				continue;
			} else{
				// Keep only source code directly related to the subject under test
				if(filename.find(KnobSourceFilter.Value()) == string::npos){
					continue;			
				}
				if (bPrintFileName) {
					if(VERBOSE){
						cout << ">" << filename << "(line " << line << endl;
					}
					bPrintFileName = false;
				}
			} // end of if (filename.empty())

			if(VERBOSE){
				cout << ">>0x" << INS_Address(ins) << " " << INS_Disassemble(ins) << endl;
			}
			//INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)docount, IARG_END);
			// Target on instrumenting loops
			if(INS_IsBranch(ins)){
				if(!INS_IsRet(ins) && !INS_IsSysret(ins)){
					if(INS_HasFallThrough	(ins)){ // filter out unconditional jump
						string lineNum;          // string which will contain the result
						ostringstream convert;   // stream used for the conversion
						convert << line;      // insert the textual representation of 'Number' in the characters in the stream
						lineNum = convert.str(); // set 'Result' to the contents of the stream
						//cout << "lineNum" << lineNum << "(" << line << ")" <<endl; 
						string sourceInfo = filename+"_"+lineNum;

						// Record this branch, get source line
						ForLoop *forLoop = new ForLoop();
						// Initialization
						forLoop->id = INS_Address(ins);
						forLoop->numOfIter = 0;
						forLoop->numOfIns = 0;
						forLoop->numOfInsSinceLast = 0;	
						forLoop->sourceInfo = sourceInfo;
						forLoop->assembly = INS_Disassemble(ins);
						forLoop->secElapsed = 0;
						forLoop->nanoElapsed = 0;
						//forLoop->operand = INS_OperandImmediate(ins,1);
						// Add to vector
						ForLoopMap.insert(make_pair(INS_Address(ins), forLoop));
						if(VERBOSE) {
							cout << "Loop stars instruction-" << INS_Disassemble(ins) << endl;	
						}

						BBL nextBbl = BBL_Next(bbl);
						if(BBL_Valid(nextBbl)){
							INS closeLoopIns = BBL_InsHead(nextBbl);
							if(VERBOSE){
								cout << "Loop ends instruction-" << INS_Disassemble(closeLoopIns) << endl;	
							}
							// Use the jump instruction address as the ID of the loop
							INS_InsertCall(closeLoopIns, IPOINT_BEFORE, (AFUNPTR)CloseForLoop, IARG_ADDRINT, INS_Address(ins), IARG_END);
						}	
						INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)UpdateForLoopCount,IARG_INST_PTR,IARG_CONST_CONTEXT, IARG_END);
						// Count only conditional instructions
						//INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)docount, IARG_END);
					} // if INS_HasFallThrough
				} // if INS_IsBranch
			}// if INS_IsBranch
		} // for INS      
	} // for BBL
	//BBL_InsertCall(bbl, IPOINT_BEFORE, (AFUNPTR)docount, IARG_INST_PTR, IARG_CONTEXT, IARG_UINT32, icount, IARG_END);
} // Trace

VOID Routine(RTN rtn, VOID *v)
{
	// The RTN goes away when the image is unloaded, so save it now
	// because we need it in the fini
	if(VERBOSE){
		cout << "<<<" << RTN_Name(rtn);
	}
	RTN_Open(rtn);
	INS head = RTN_InsHeadOnly(rtn);
	INS_InsertCall(head, IPOINT_BEFORE, (AFUNPTR)PrintRtnHead, IARG_INST_PTR, IARG_CONST_CONTEXT, IARG_END);

	for( INS ins = RTN_InsHead(rtn); INS_Valid(ins); ins = INS_Next(ins) ){
		if( INS_IsRet(ins) )
		{	
			INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)PrintRtnReturn,IARG_INST_PTR,IARG_CONST_CONTEXT,IARG_END);
		}
	}

	RTN_Close(rtn);
	if(VERBOSE){
		cout << ">>>" << endl;
	}
} // Routine

// Write trace file
VOID LogToTraceFile(){
	UINT32 secSum=0;
	UINT64 nanoSum=0;
	UINT64 numOfIter=0;

	if(!isLcdExist){
		loopCountData << 
			"LoopId,ConfigName,ConfigVal,TestId,NumOfInst,ExeTime,Assembly,NumOfIteration,outputDir,sourceInfo"
			<< endl;
	}

	loopCountData.setf(ios::showbase);
	loopCountData << "ppid(pid)" << getppid() << " (" << getpid() << ")" << endl;
	for(map<ADDRINT, ForLoop*>::iterator it=ForLoopMap.begin(); it!=ForLoopMap.end(); ++it){
		if(it->second->numOfIter !=0){ // Filter out non loop jumps
			loopCountData << hex << it->second->id << ","
				<< KnobConfigName.Value() << ","
				<< KnobConfigVal.Value() << ","
				<< dec << KnobTestId.Value() << ","
				<< it->second->numOfIns << ","
				<< fixed << (float)GetMsFromS(it->second->secElapsed) + GetMsFromNanoS(it->second->nanoElapsed) << "," 
				<< it->second->assembly << "," 
				<< it->second->numOfIter << ","
				<< KnobOutputDir.Value() << ","
				<< it->second->sourceInfo  
				<< endl;

			// Update counters for calculating average
			secSum += it->second->secElapsed;
			nanoSum += it->second->nanoElapsed;
			numOfIter += it->second->numOfIter;
		} // end of if

		// Delete ForLoop* pointer
		delete it->second;	 
		ForLoopMap.erase(it);
	}

	// Get execution time average
	// Make sure the data type is big enough to hold all the bits without overflow
	if(enableLoopToTime){
		UINT64 secAvg=secSum/numOfIter;
		UINT64 nanoAvg=nanoSum/numOfIter;
		loopToExeTime << "AvgExeTime," << 1000000000*secAvg+nanoAvg 
			<< "," << secAvg << "," << nanoAvg << endl;
	}
	// Print header
	if(!isScdExist){
		fprintf(sysCallData,"CallNum,TestId,NumOfCalls,ExeTime,ConfigVal\n");
	}
	// Output system call data
		for(auto it = sysCallSet.begin(); it != sysCallSet.end(); it++){
			fprintf(sysCallData,"%u,%u,%lu,%lu,%s\n",(*it)->sysCallNum, KnobTestId.Value(),
				(*it)->callCounter, (*it)->exeTime,
				KnobConfigVal.Value().c_str());
	}
	fflush(sysCallData);
	if(enableRtnCall){
		// Print header
		if(!isRcdExist){
			rtnCallData << "RtnName,TestId,NumOfIns,NumOfCalls,ConfigVal" << endl;
		}
		// Output routine call data
		for(map<string, struct RoutineStats*>::iterator rsIter = rtnInfoMap.begin(); rsIter!=rtnInfoMap.end(); ++rsIter){
			rtnCallData << rsIter->second->name << ","
				<< dec << KnobTestId.Value() << "," 
				<< rsIter->second->numOfIns << "," 
				<< rsIter->second->numOfCalls << ","
				<< KnobConfigVal.Value() << endl; 

			// Remove struct pointer
			delete rsIter->second;
			rtnInfoMap.erase(rsIter);
		}
	} // enable routine call data
	// Print header
	if(trackPthread){
		if(!isPcdExist){
			pthreadCallData << "name" << endl;
		}
	}
} //LogToTraceFile

// This function is called when the application exits
// Or when the process terminates in multi process programs
VOID Fini(INT32 code, VOID *v)
{
	LogToTraceFile();
	// Clear data
	loopStack.clear();
	ForLoopMap.clear();

} // Fini()
/* ===================================================================== */
/* Print Help Message                                                    */
/* ===================================================================== */
INT32 Usage()
{
	cerr << "This tool counts the number of loops executed" << endl;
	cerr << endl << KNOB_BASE::StringKnobSummary() << endl;
	return -1;
}

/* ===================================================================== */
/* Main                                                                  */
/* ===================================================================== */
/*   argc, argv are the entire command line: pin -t <toolname> -- ...    */
/* ===================================================================== */
// TODO: filter out noise jumps such as assertion
// TODO: figure out how pin handles multi-threading, do they all 
// get executed from main function?
int main(int argc, char * argv[])
{
	// Initialize pin
	if (PIN_Init(argc, argv)){
		return Usage();
	}
	PIN_InitSymbols();
	// Write to a file since cout and cerr may be closed by the application
	// Print header only once upon first creating the file in each thread
	ifstream ifs(LOOP_CNT_DATA);
	if(ifs.is_open()){
		isLcdExist = true;
	}

	ifstream ifsRcd(ROUTINE_DATA);
	if(ifsRcd.is_open()){
		isRcdExist = true;
	}

	ifstream ifsSysCall(SYS_CALL_DATA);
	if(ifsSysCall.is_open()){
		isScdExist = true;
	}

	// pthread trace
	if(trackPthread){
		ifstream ifsPthCall(PTHREAD_CALL_DATA);
		if(ifsPthCall.is_open()){
			isPcdExist = true;	
		}	
		pthreadCallData.open(KnobOutputDir.Value()+PTHREAD_CALL_DATA,ofstream::app);
	}
	//	loopCountData << ifs.is_open() << "," << ifs.good() << endl;
	// TODO: move file names to global const variables
	loopCountData.open(KnobOutputDir.Value()+LOOP_CNT_DATA,ofstream::app);
	if(enableLoopToTime) loopToExeTime.open(KnobOutputDir.Value()+DATA_DIR+"loopToExeTime.convert",ofstream::app);
	if(enableRtnTrace) routineTrace.open(KnobOutputDir.Value()+DATA_DIR+"routine.trace",ofstream::app);
	if(enableRoutineData) routineData.open(KnobOutputDir.Value()+DATA_DIR+"routine.data",ofstream::app);
	if(enableRtnCall) rtnCallData.open(KnobOutputDir.Value()+ROUTINE_DATA,ofstream::app);
	sysCallData = fopen((KnobOutputDir.Value()+SYS_CALL_DATA).c_str(), "a");

	// Register Instruction to be called to instrument instructions
	INS_AddInstrumentFunction(Instruction, 0);
	// Print call stack
	IMG_AddInstrumentFunction(ImageLoad, 0);
	RTN_AddInstrumentFunction(Routine, 0);	
	TRACE_AddInstrumentFunction(Trace,0);
	// Register Fini to be called when the application exits
	PIN_AddFiniFunction(Fini, 0);
	//	PIN_AddFollowChildProcessFunction(FollowChild,0);
	//	PIN_AddForkFunction(FPOINT_BEFORE,ForkCallBack,0);

	PIN_AddSyscallEntryFunction(SyscallEntry, 0);
	PIN_AddSyscallExitFunction(SyscallExit, 0);
	// Start the program, never returns
	PIN_StartProgram();

	loopCountData.close();
	if(enableLoopToTime) loopToExeTime.close();
	if(enableRtnTrace) routineTrace.close();
	if(enableRoutineData) routineData.close();
	if(enableRtnCall) rtnCallData.close();
	fclose(sysCallData);
	if(trackPthread) pthreadCallData.close();
	return 0;
}
