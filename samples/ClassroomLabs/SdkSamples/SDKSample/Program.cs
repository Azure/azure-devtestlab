﻿using System;

namespace SDKSample
{
    internal class Program
    {
        private static void Main(string[] args)
        {
            try
            {
                if (args.Length == 0)
                {
                    Console.WriteLine("Missing required parameters.");
                    return;
                }

                switch (args[0])
                {
                    case "getPublicRdpFilesForLab":
                        {
                            GetPublicRdpFilesForLab.CreateRdpFiles().Wait();

                            Console.ForegroundColor = ConsoleColor.Green;
                            Console.WriteLine($"Saved all RDP files!");
                            Console.ResetColor();

                            break;
                        }
                    case "getPrivateRdpFilesForLab":
                        {
                            GetPrivateRdpFilesForLab.CreateRdpFiles().Wait();

                            Console.ForegroundColor = ConsoleColor.Green;
                            Console.WriteLine($"Saved all RDP files!");
                            Console.ResetColor();

                            break;
                        }
                    case "getPublicRdpFilesForUser":
                        {
                            GetRdpFilesForUser.CreateRdpFiles().Wait();

                            Console.ForegroundColor = ConsoleColor.Green;
                            Console.WriteLine($"Saved all RDP files!");
                            Console.ResetColor();

                            break;
                        }
                }
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine(ex.ToString());
                Console.ResetColor();
            }
            finally
            {
                Console.WriteLine();
                Console.WriteLine("Press <ENTER> to continue.");
                Console.ReadLine();
            }
        }
    }
}
