// Copyright (c) Microsoft Corporation. All rights reserved.

using System;
using System.Diagnostics;
using System.Linq;
using System.ServiceProcess;
using System.IO;
using System.Timers;

namespace SeleniumGridSetupService
{
    public partial class SeleniumGridSetupService : ServiceBase
    {
        private static Process SeleniumGridJavaProcess; // Maintains the pid of the spawned java process
        private static int InitialRetryCount = 45;
        private static int RetriesLeft;
        private static bool IsSetupSuccessful;
        private static string SetupDirectory;
        private static Timer timer;
        private static InputConfig inputConfig;
        private static ElapsedEventHandler elapsedEventHandler;
        private static TextWriterTraceListener textWriterTraceListener;

        public SeleniumGridSetupService()
        {
            InitializeComponent();
        }

        protected override void OnStart(string[] args)
        {
            try
            {
                SeleniumGridJavaProcess = null;
                RetriesLeft = InitialRetryCount;
                IsSetupSuccessful = false;
                SetupDirectory = Environment.ExpandEnvironmentVariables(Environment.GetEnvironmentVariable("SystemDrive")) + @"\SeleniumGridSetup";

                if (textWriterTraceListener == null)
                {
                    textWriterTraceListener = new TextWriterTraceListener(Path.Combine(SetupDirectory, "SeleniumGridSetupServiceTrace.log"));
                    Trace.Listeners.Add(textWriterTraceListener);
                }

                WriteTrace(string.Format("Starting setup."));
                WriteTrace(string.Format("Setup directory set to {0}", SetupDirectory));

                // Store the arguments received on first execution in a file and read them on service restart
                if (args.Count() > 0)
                {
                    for (int i = 0; i < args.Count(); i++)
                    {
                        args[i] = args[i].Substring(1, args[i].Length - 1);  // Strip away the leading '/' from the parameters received
                    }

                    inputConfig = new InputConfig(args);
                    File.WriteAllText(Path.Combine(SetupDirectory, "Arguments.txt"), inputConfig.ToString());
                    WriteTrace(string.Format("Successfully saved the received arguments to Arguments.txt"));
                }
                else
                {
                    inputConfig = InputConfig.CreateInputConfig(File.ReadAllText(Path.Combine(SetupDirectory, "Arguments.txt")));
                    WriteTrace(string.Format("Successfully read the saved arguments from Arguments.txt"));
                }

                File.WriteAllText(Path.Combine(SetupDirectory, "logs", "SetupStatus.txt"), "");  // Overwrite content from previous setups if any and create a blank status file
                File.WriteAllText(Path.Combine(SetupDirectory, "logs", "SetupLogs.txt"), "");  // Overwrite content from previous setups if any and create a blank log file

                timer = new System.Timers.Timer();  // Timer to poll setup status
                timer.Interval = 1000; // 1 second
                elapsedEventHandler = new ElapsedEventHandler(this.OnTimer);
                timer.Elapsed += elapsedEventHandler;
                timer.Start();
            }
            catch (Exception ex)
            {
                WriteTrace(ex.ToString());
                throw;
            }
        }

        public void ProcessMonitor(object sender, System.Timers.ElapsedEventArgs args)
        {
            try
            {
                Process.GetProcessById(SeleniumGridJavaProcess.Id);
            }
            catch (ArgumentException)
            {
                WriteTrace("Selenium-grid java process has unexpectedly stopped. Trying to bring it back up.");
                timer.Elapsed -= elapsedEventHandler;
                OnStart(new string[0]);
            }
        }

        public void OnTimer(object sender, System.Timers.ElapsedEventArgs args)
        {
            if (RetriesLeft == InitialRetryCount)
            {
                try
                {
                    // Create and start the selenium node/hub java process
                    SeleniumGridJavaProcess = new Process();
                    SeleniumGridJavaProcess.StartInfo.WorkingDirectory = SetupDirectory;
                    SeleniumGridJavaProcess.StartInfo.FileName = "java";
                    SeleniumGridJavaProcess.StartInfo.Arguments = "-jar \"" + Path.Combine(SetupDirectory, inputConfig.SeleniumGridJarFile) + "\" -role " + inputConfig.Role + " " + inputConfig.HubRegisterUrl + " " + inputConfig.ConfigFile + " " + inputConfig.AdditionalParameters;
                    SeleniumGridJavaProcess.StartInfo.UseShellExecute = false;
                    // TODO : Redirect standard stream just in case selenium changes the stream to which it outputs the messages, in the future
                    SeleniumGridJavaProcess.StartInfo.RedirectStandardError = true;
                    SeleniumGridJavaProcess.ErrorDataReceived += new DataReceivedEventHandler(OutputHandler);
                    SeleniumGridJavaProcess.Start();
                    SeleniumGridJavaProcess.BeginErrorReadLine();
                    WriteTrace("Selenium-grid java process started successfully.");
                }
                catch (Exception ex)
                {
                    WriteTrace(ex.ToString());
                    throw;
                }
            }

            if (IsSetupSuccessful)
            {
                try
                {
                    File.WriteAllText(Path.Combine(SetupDirectory, "logs", "SetupStatus.txt"), "Success");
                    WriteTrace("Setup successful.");
                    timer.Elapsed -= elapsedEventHandler;
                    elapsedEventHandler = new ElapsedEventHandler(this.ProcessMonitor);
                    timer.Elapsed += elapsedEventHandler;
                    timer.Interval = 5000;
                }
                catch (Exception ex)
                {
                    WriteTrace(ex.ToString());
                }
                return;
            }

            if (RetriesLeft >= 0)
            {
                RetriesLeft--;
                return;
            }

            try
            {
                File.WriteAllText(Path.Combine(SetupDirectory, "logs", "SetupStatus.txt"), "Failure");
                WriteTrace("Setup failed.");
                timer.Stop();
            }
            catch (Exception ex)
            {
                WriteTrace(ex.ToString());
            }
        }

        static void OutputHandler(object sendingProcess, DataReceivedEventArgs outLine)
        {
            try
            {
                if (outLine == null || outLine.Data == null)
                {
                    return;
                }

                // Append output to the SetupLogs file 
                File.AppendAllText(Path.Combine(SetupDirectory, "logs", "SetupLogs.txt"), outLine.Data.ToString() + "\r\n");

                // Check for successful setup of the hub/node by sniffing through the selenium grid setup logs
                if (outLine.Data.ToString().Contains("Selenium Grid hub is up and running") ||
                    outLine.Data.ToString().Contains("The node is registered to the hub and ready to use"))
                {
                    IsSetupSuccessful = true;
                }
            }
            catch (Exception ex)
            {
                WriteTrace(ex.ToString());
            }
        }

        protected override void OnStop()
        {
            // Terminate the hub/node java process
            try
            {
                SeleniumGridJavaProcess.Kill();
                WriteTrace(string.Format("Successfully killed the node/hub process with id {0}", SeleniumGridJavaProcess.Id));
            }
            catch (Exception ex)
            {
                WriteTrace(ex.ToString());
            }
        }

        private static void WriteTrace(string message)
        {
            Trace.WriteLine(DateTime.Now + ": " + message);
            Trace.Flush();
        }
    }
}