using OpenQA.Selenium;
using OpenQA.Selenium.Firefox;
using OpenQA.Selenium.IE;
using OpenQA.Selenium.Chrome;


namespace vsarSeleniumDemo
{
    class Program
    {
        static void Main(string[] args)
        {
            // Internet Explorer test

            IWebDriver IEDriver = new InternetExplorerDriver(@"C:\tools\selenium");
            IEDriver.Url = "http://azure.microsoft.com";

            // Chomre Driver Test 

            IWebDriver chromeDriver = new ChromeDriver(@"C:\tools\selenium");
            chromeDriver.Url = "http://azure.microsoft.com";

            // FireFox Driver Test

            IWebDriver firefoxDriver = new FirefoxDriver();
            firefoxDriver.Url = "http://azure.microsoft.com";
            
        }
    }
}
