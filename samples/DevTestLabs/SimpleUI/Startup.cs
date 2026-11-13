using System;
using System.Text;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.SpaServices.ReactDevelopmentServer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace SimpleDtlUI
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;

            // Ensure that the Application Settings have been updated by the user of this code sample
            // These settings can either by set in the Configuration pane of the App Service in the Azure portal, or in the appsettings.json file
            var _labResourceGroupName = configuration.GetValue<string>("LabResourceGroupName");
            var _labName = configuration.GetValue<string>("LabName");
            var _subscriptionId = configuration.GetValue<string>("SubscriptionId");

            string placeholderValue = "<set in Azure>";
            bool labResourceGroupSet = !string.Equals(_labResourceGroupName, placeholderValue, StringComparison.InvariantCultureIgnoreCase);
            bool labNameSet = !string.Equals(_labName, placeholderValue, StringComparison.InvariantCultureIgnoreCase);
            bool subscriptionIdSet = !string.Equals(_subscriptionId, placeholderValue, StringComparison.InvariantCultureIgnoreCase);

            if (labResourceGroupSet && labNameSet && subscriptionIdSet)
            {
                return;
            }

            StringBuilder errorMessage = new StringBuilder();
            if (!labResourceGroupSet)
            {
                errorMessage.Append("LabResourceGroupName must be set in Application Settings. ");
            }

            if (!labNameSet)
            {
                errorMessage.Append("LabName must be set in Application Settings. ");
            }

            if (!subscriptionIdSet)
            {
                errorMessage.Append("SubscriptionId must be set in Application Settings. ");
            }

            errorMessage.Append("Please refer to the README for additional information.");

            throw new InvalidOperationException(errorMessage.ToString());
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {

            services.AddControllersWithViews();

            // In production, the React files will be served from this directory
            services.AddSpaStaticFiles(configuration =>
            {
                configuration.RootPath = "ClientApp/build";
            });

            services.AddApplicationInsightsTelemetry();
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }

            app.UseHttpsRedirection();
            app.UseStaticFiles();
            app.UseSpaStaticFiles();

            app.UseRouting();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllerRoute(
                    name: "default",
                    pattern: "{controller}/{action=Index}/{id?}");
            });

            app.UseSpa(spa =>
            {
                spa.Options.SourcePath = "ClientApp";

                if (env.IsDevelopment())
                {
                    spa.UseReactDevelopmentServer(npmScript: "start");
                }
            });
        }
    }
}
