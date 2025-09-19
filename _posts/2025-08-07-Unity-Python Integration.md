---
title: "Unity-Python Integration"
date: 2025-08-07
categories: 프로그래밍
tags: C# Python Robospital Unity3D
permalink: /posts/unity-python-integration
description: "Unity3D에서 Python 인터프리터를 통합하는 완전한 가이드. 프로세스 실행, 파이프 연결, AST 파싱, 디버거 연동부터 Pyflakes까지 실무 구현 과정."
excerpt: "Unity3D 게임에서 Python 코드를 실시간으로 실행하고 디버깅할 수 있는 통합 시스템 구현 과정을 다룹니다."
---

기획 단계에서 Robospital을 **Python 교육용 게임**으로, **Unity3D**를 이용해 만들기로 결정했다. 따라서 사용자가 게임 안에서 코드를 작성하고, 그 코드를 곧바로 실행할 방법이 필요했다. 또한 warning이나 syntax error 하이라이팅 정보를 받아, 게임 화면에 시각적 피드백을 남길 수 있다면 초보자에게 더 직관적인 피드백을 줄 수 있을 것 같았다. 따라서 Python 코드를 문자열로 받아 Unity3D에서 직접 실행할 수 있는 방법에 대해 탐색하기 시작했다. 

---

# 탐색

※ Robospital을 기획하던 2020-2021년 기준으로 작성되었습니다.

Python에 관련된 .NET 라이브러리를 찾기 시작했다. IronPython과 Python.NET을 검토해봤는데, 몇 가지 이유로 선택할 수 없었다.

1. IronPython
    
    IronPython은 .NET 환경에 맞춘 Python 인터프리터인데, 당시에 Python 2의 지원 중심이었고, Python3의 지원은 느리게 업데이트 되는 중이었다. (현재는 Python 3.4까지 지원하고 있는 것으로 보인다.) 그리고 일부 문법 호환이 완벽하지 않거나, 외부 라이브러리 import가 아쉬운 부분이 있었다.
    
2. Python.NET
    
    Pythonnet은 python을 임베딩할 수 있는 라이브러리지만, 당시에는 공식 문서가 직관적이지 않았고, Python 소스 코드를 C#에서 실행하는 예제나 정보가 부족했다. 지금이라면 Pythonnet을 선택할 것 같은데, 당시에는 구현에 대한 확신이 들지 않아서 다른 방법을 찾게 됐다.
    
3. **Python 프로세스 만들어서 통신하기**
    
    결정적으로 라이브러리 위에서 원하는 기능들을 모두 구현할 수 있을 것이라는 확신이 들지 않아서, 새로운 python 프로세스를 만들어, pipe로 통신하는 구조로 만들기로 결정했다. 두 프로세스를 관리해야 한다는 부담은 있었지만, 파이썬 문법이나 코드에 신경을 적게 들일 수 있고, 원하는 기능들을 모두 만들어 낼 수 있을 거라는 확신은 가질 수 있었다.
    

---

# 구현

파이썬 프로세스를 실행하고 Unity에서 Python으로 메시지 (소스 코드)를 전달하는 코드를 작성했다.

## 파이썬 프로세스 실행 하기

Unity C# 스크립트에서 Python 프로세스를 실행하고, stdin, stdout을 연결하는 과정이다.

![image.png](\assets\images\Unity-Python Integration\image.png)

```csharp
// Unity
using System;
using System.Diagnostics;
using System.IO;
using System.Text;

using UnityEngine;

public class PythonInterface : MonoBehaviour
{
	private Process cmd = null;
	private StreamWriter stdin = null;
	private readonly string interfacePath = "interface.py";
	private readonly string pythonPath = "python.exe";
	
	private int RunCmd()
	{
		if (cmd != null)
		{
			//error message
			print("python is already running");
			return -1;
		}
		cmd = new Process();
		cmd.StartInfo.FileName = pythonPath;
		cmd.StartInfo.Arguments = BuildArgumetns();

		cmd.StartInfo.UseShellExecute = false;
		cmd.StartInfo.CreateNoWindow = true;

		cmd.StartInfo.RedirectStandardInput = true;
		cmd.StartInfo.RedirectStandardOutput = true;
		cmd.StartInfo.RedirectStandardError = true;

		cmd.EnableRaisingEvents = true;
		cmd.Exited += new EventHandler(ProcessExited);
		cmd.OutputDataReceived += new DataReceivedEventHandler(ReadStdout);
		cmd.ErrorDataReceived += new DataReceivedEventHandler(ReadStderr);

		cmd.StartInfo.StandardOutputEncoding = Encoding.GetEncoding("utf-8");
		cmd.StartInfo.StandardErrorEncoding = Encoding.GetEncoding("utf-8");

		cmd.Start();

		stdin = cmd.StandardInput;

		cmd.BeginOutputReadLine();
		cmd.BeginErrorReadLine();

		return cmd.Id;
	}
	
	private string BuildArgumetns()
	{
		return interfacePath;
	}
	
	//stdout 콜백
	private void ReadStdout(object sender, DataReceivedEventArgs e)
	{
		if (!String.IsNullOrEmpty(e.Data))
		{
			Debug.Log(e.Data.ToString());
			//Do something
		}
	}
	
	//stderr 콜백
	private void ReadStderr(object sender, DataReceivedEventArgs e)
	{
		if (!String.IsNullOrEmpty(e.Data))
		{
			Debug.Log(e.Data.ToString());
			//Do something
		}
	}
	
	//process exit 콜백
	private void ProcessExited(object sender, System.EventArgs e)
	{
	}
}
```

## 메시지 박스 만들기

Unity3D에서 MonoBehaviour가 동작하는 메인 스레드는 단일 스레드로 돌아간다. 따라서, MonoBehaviour 내에서 직접적인 멀티스레딩은 지원되지 않는다. 

예를 들어, 메인 스레드가 아닌 다른 스레드에서 유니티 GameObject의 속성이나, UI에 접근할 수 없다. 따라서 Python 프로세스에서 온 신호의 콜백이 UI나 GameObject에 영향을 미칠 수 없다.

이 것을 극복하기 위해 사이에 메시지 박스 (Queue)를 두고, 콜백이 메시지를 쌓아두게 한다. 그리고 Unity의 메인 스레드가 주기적으로 메시지 박스를 체크해서 쌓여있는 메시지를 처리하는 방식을 쓴다.

![image.png](\assets\images\Unity-Python Integration\image%201.png)

```csharp
// Unity
using System.Collections.Generic;

public class MessageBox
{

	private Queue<string> messageQueue = new Queue<string>();

	public void PushData(string data)
	{
		messageQueue.Enqueue(data);
	}

	public string GetData()
	{
		if (messageQueue.Count > 0)
			return messageQueue.Dequeue();
		else
			return string.Empty;
	}
	
	public bool MessageExisting()
	{
		if (messageQueue.Count > 0)
			return true;
		else
			return false;

	}

	public void ClearMessage()
	{
		messageQueue.Clear();
	}
}
```

```csharp
// Unity
using System.Collections;
using UnityEngine;

public class UnityManager: MonoBehaviour
{
	//반복하면서 메시지 확인
	virtual public IEnumerator CheckQueue()
	{
		while (true)
		{
			string data = messageBox.GetData();
			data.DoSomething();
			yield return null;
		}
	}
}
```

## 파이프 연결, 코드 전송과 실행

게임에서 작성한 코드를 파이썬으로 넘기는 과정. 코드를 전달할 파이프를 연결한다.

![image.png](\assets\images\Unity-Python Integration\image%202.png)

```csharp
// Unity
using TMPro;
using System.IO.Pipes;

private byte[] buffer = null;
private TMP_InputField codeEditor;
	
	//코드 파이프 실행
	private void RunCodePipeWait()
	{
		string code = codeEditor.Text;
		buffer = Encoding.UTF8.GetBytes(code);
		
		string pipeName = "CodePipe";
		
		codePipe = new NamedPipeServerStream(pipeName);
		codePipe.BeginWaitForConnection(new AsyncCallback(CodePipeConnectionCallback), codePipe);
	}
	
	//코드 파이프 콜백
	private void CodePipeConnectionCallback(IAsyncResult iar)
	{
		BinaryWriter writer = new BinaryWriter(codePipe);
		writer.Write(buffer, 0, buffer.Length);
		buffer = null;
	}
	
	//Argument로 코드 버퍼 길이 전달
	private string BuildArgumetns()
	{
		return interfacePath + " " + buffer.Length.ToString();
	}
```

```python
#Python
#파이프에서 코드 읽어오기
def GetCode(bufferSize, pipePath):
	f = open(pipePath, 'r+b', 0)
	try:
		code = f.read(bufferSize).decode('utf-8')
	except OSError as err:
		raise Exception("pipePath: {pipePath}, bufferSize: {bufferSize}, Error: {err}".format(pipePath, bufferSize, err))
	f.close()
	return code
	
def main(args):
	codeBufferSize = int(args[1])
	pipePath = '\\\\.\\pipe\\' + "CodePipe"
		
	code = GetCode(codeBufferSize, pipePath)
	#코드 실행
	exec(code)
	
if __name__ == '__main__':
	try:
		main(sys.argv)
	except Exception as e:
		print(e)
```

## 클린업 루틴

게임을 종료할 때 파이프와 프로세스를 정리하는 루틴이다.

```csharp
// Unity
public void CleanCmd()
{
	controllerCeaning = true;
	if (codePipe != null)
	{
		try
		{
			if (codePipe.IsConnected)
			{
				codePipe.Disconnect();
			}
		}
		catch { }
		codePipe.Dispose();
		codePipe.Close();
		codePipe = null;
	}
	if (cmd != null)
	{
		try
		{
			if (!cmd.HasExited)
			{
				cmd.Kill();
			}
		}
		catch { }
		cmd.Close();
		cmd = null;
	}
	if (stdin != null)
		stdin = null;
}

private void OnApplicationQuit()
{
	CleanController();
}

```

---

# 추가적인 기능들

Robospital을 교육용 게임으로 만들기 위해 필요했던 코드를 작성했다. 피드백, 코드 실행 시각화, 변수 추적 등의 기능 추가를 위해 코드를 분석하고, 디버거를 이용하는 방법이 필요했다. 

## Python → Unity 시그널 파이프 추가 연결

몇몇 기능들을 추가하기 위해서, Python에서 Unity로 신호를 전달할 수 있는 추가적인 통신 수단이 필요했다. 기존 코드 파이프를 사용할 수도 있지만, 관리를 용이하게 하기 위해 추가적인 파이프를 하나 연결했다. 

![image.png](\assets\images\Unity-Python Integration\image%203.png)

```csharp
//Unity
	
	//시그널 파이프 연결
	private void RunSignalPipeWait(string pipeName)
	{
		signalPipe = new NamedPipeServerStream(pipeName);
		signalPipe.BeginWaitForConnection(new AsyncCallback(SingalPipeConnectionCallback), signalPipe);
	}
	
	//시그널 파이프가 연결됐을 때 콜백
	private void SingalPipeConnectionCallback(IAsyncResult iar)
	{
		{
			NamedPipeServerStream signalPipe = (NamedPipeServerStream)iar.AsyncState;
			signalPipe.BeginRead(buffer2, 0, signalBufferSize, SignalCallback, null);
		}
	}
	
	//시그널이 왔을 때 콜백
	private void SignalCallback(IAsyncResult ar)
	{
		int readBytes = signalPipe.EndRead(ar);
		if (readBytes > 0)
		{
			string str = Encoding.UTF8.GetString(buffer2);
			//do something
		}
		buffer2 = new byte[signalBufferSize];
		signalPipe.BeginRead(buffer2, 0, signalBufferSize, SignalCallback, null);
	}
```

```python
#Python

#시그널을 보내는 파이프 열기
def WriteToSignalPipe(info: str):
	global signalPipe
	signalPipe.write((info+' ').encode('utf-8'))
		
signalPipe = open("SignalPipe", 'w+b', 0)
```

## Abatract Syntax Tree (추상 구문 트리, AST) 파싱

[https://docs.python.org/ko/3.13/library/ast.html](https://docs.python.org/ko/3.13/library/ast.html)

AST는 Python 소스 코드를 문법 구조에 따라 트리 형태로 표현한 자료구조로, 코드를 분석하거나 검사할 때 사용한다. Robospital에서는 import할 수 있는 모듈을 제한하거나, 연습문제에서 피드백을 주기 위해 코드를 분석하는데 사용했다.

아래 코드는 제한된 import 모듈이 입력됐을 때 메시지를 보내는 파이썬 코드

![image.png](\assets\images\Unity-Python Integration\image%204.png)

```python
#Python

import ast
import importlib.util

class NodeTransformer(ast.NodeTransformer):
	safeModules = (
		'Safe Module Name 1',
		'Safe Module Name 2',
		)

	#코드에서 import를 방문했을 때
	def visit_Import(self, node):
		lineno = getattr(node, 'lineno', None)
		for alias in node.names:
			exists = importlib.util.find_spec(alias.name) is not None
			if exists:
				if alias.name not in self.safeModules:
					message = "ImportError module '{name}' is not allowed".format(name=alias.name)
					#send message
			else:
				message = "ModuleNotFoundError No module named '{name}'".format(name=alias.name)
				#send message
		return self.generic_visit(node)

	#코드에서 from ... import ... 를 방문했을 때
	def visit_ImportFrom(self, node):
		lineno = getattr(node, 'lineno', None)
		exists = importlib.util.find_spec(node.module) is not None
		if exists:
			if node.module not in self.safeModules:
				message = "ImportError module '{name}' is not allowed".format(name=alias.name)
				#send message
		else:
			message = "ModuleNotFoundError No module named '{name}'".format(name=alias.name)
			#send message
		return self.generic_visit(node)

```

상수에 접근했을 때 정보를 메시지로 보내는 파이썬 코드

```python
#Python
class NodeTransformer(ast.NodeTransformer):	

	def visit_Constant(self, node):
		lineno = getattr(node, 'lineno', None)
		message = 'ast constant {lineno} {type} {value}'.format(lineno=lineno, type=type(node.value).__name__, value=node.value)
		#send message
		return self.generic_visit(node)
```

AST 파싱 후 코드를 실행하는 파이썬 main 코드

```python
#Python
import ast
import ModifiedNodeTransformer

def main(args):
	codeBufferSize = int(args[1])
	pipePath = '\\\\.\\pipe\\' + "CodePipe"
		
	code = GetCode(codeBufferSize, pipePath)
	
	#노드 파싱
	node = ast.parse(code)
	node = NodeTransformer().visit(node)
	
	#ast에서 변경된 코드를 실행
	byte_code = compile(node, filename="fileName", mode="exec")
	exec(byte_code)
	
if __name__ == '__main__':
	try:
		main(sys.argv)
	except Exception as e:
		print(e)
```

## 파이썬 디버거 pdb 연결과 input 함수 조정

[https://docs.python.org/ko/3.13/library/pdb.html](https://docs.python.org/ko/3.13/library/pdb.html)

Python은 pdb라는 대화형 소스코드 디버거를 제공한다. 일반적으로 pdb는 터미널 환경에서 사용하기 때문에, 실행 위치나, 변수 값, 함수 호출 등 코드 실행 상태를 UI에 보여주기 어렵다. 

따라서 기존 pdb를 상속해서 각종 디버깅 신호를 파이프 메시지로 분리해서 전송했다. 그리고 신호를 받은 Unity에서는 초보자의 이해를 돕기 위해 코드 하이라이트, 변수 탐색기 업데이트 등, 코드의 실행 과정을 모두 시각화 했다. 

pdb를 디버거로 사용할 때 문제점은 pdb의 커맨드와 사용자 코드의 print, input을 구분하기 어렵다는 점이다. 따라서, 두 가지 작업이 필요했다.

1. pdb의 프롬프트 “(pdb)”를 stdout이 아니라, 시그널 파이프를 통해 전달해서, 사용자 코드의 output과 분리한다. pdb의 경우 출력부를 파이프로 변경하는 간단한 변경이 있었다.
2. 코드에서 input()을 호출할 경우, 시그널 파이프를 통해 input이 들어올 차례임을 Unity에 전달한다.

![image.png](\assets\images\Unity-Python Integration\image%205.png)

```python
#Python

import builtins
from ModifiedPDB import modified_pdb

class MoifiedBuiltins():	
	new_globals = {}
	def __init__(self):
		#builtins 복사
		modifiedBuiltins = dict(vars(builtins))
		#input 함수 대체
		modifiedBuiltins['input'] = _input_
		#dictinary 생성
		newGlobals = {'__builtins__': modifiedBuiltins}

#수정된 input 함수
def _input_(*prompt):
	#프롬프트 길이 확인
	if len(prompt) > 1:
		raise TypeError("input expected at most 1 arguments, got {length}".format(length=len(prompt)))
		
	#프롬프트 유무에 따라 시그널 보내기
	if prompt:
		WriteToSignalPipe("inputWithPrompt")
		print(*prompt, end = "")
	else:
		WriteToSignalPipe("input")

	val = input()

	return val
	
def main(args):
	codeBufferSize = int(args[1])
	pipePath = '\\\\.\\pipe\\' + "CodePipe"
		
	code = GetCode(codeBufferSize, pipePath)
	
	new_globals = MoifiedBuiltins().new_globals
	
	#일반 코드 실행
	#exec(code, new_globals)
	
	#pdb로 코드 실행
	instance = modified_pdb()
	instance.run(code, new_globals)
```

## Pyflakes 연동

Pyflakes는 파이썬 소스 코드에서 기본적인 오류를 찾아주는 분석 도구이다. 유니티 코드 에디터의 수정이 끝난 후 1초 동안 입력이 없으면, 별도의 Python 프로세스를 실행해 Pyflakes로 코드의 오류를 확인했다. 

이 경우, 사용자 코드의 output과 Pyflakes의 메시지를 구분 할 필요가 없기 때문에, stdout으로 메시지를 처리하였다. 다만, Pyflakes의 정보를 Unity에서 효과적으로 구분하기 위해 reporter.py파일을 수정하여 메시지 포맷팅을 구현했다.

원래는 에러·경고 메시지를 다국어로 제공하고 싶었지만, 당시 번역의 품질과 유지보수 비용이 커서 영문 메시지로 고정하기로 결정했다. 

```python
#Python

class Reporter(object):

    def __init__(self, Stream):
        self._stdout = Stream
        self._stderr = Stream
        
    def syntaxError(self, filename, msg, lineno, offset, text):
        self._stderr.write('syntaxError:%d:%s\n' % (lineno, msg))
        
    def flake(self, message):
        self._stdout.write("warning:"+str(message))
        self._stdout.write('\n')
       

def _makeDefaultReporter():
    """
    Make a reporter that can be used when no reporter is specified.
    """
    return Reporter(sys.stdout)
```