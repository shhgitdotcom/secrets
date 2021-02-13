using ADProject.Data;
using ADProject.DbSeeder;
using ADProject.Models;
using ADProject.Service;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.HttpsPolicy;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.UI;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace ADProject
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            /*            services.AddDbContext<ADProjContext>(options =>
                            options.UseSqlServer(
                                Configuration.GetConnectionString("DefaultConnection")));*/

            services.AddAuthentication()
                .AddGoogle(options =>
                {
                    options.ClientId = "285372488193-u1s12juxxxlkh0n3en9fk26q8ei6r3sa.apps.googleusercontent.com";
                    options.ClientSecret = "CN0pBpWFi9oxLFFEclKockDV";
                });
                

            services.AddDbContext<ADProjContext>(options =>
                options.UseSqlServer(Environment.GetEnvironmentVariable("DB_CONNECTION_STRING", EnvironmentVariableTarget.User)));

            services.AddRazorPages();

            services.AddDatabaseDeveloperPageExceptionFilter();

            /*services.AddDefaultIdentity<IdentityUser<int>>(options => options.SignIn.RequireConfirmedAccount = true)
                .AddEntityFrameworkStores<ADProjContext>();*/

            //This configures identity to work with the database, uses applicationrole class to manage perms.
            //Point ASPNETCOREIDENTITY to the context.

            services.AddIdentity<ApplicationUser, ApplicationRole>(options => {
                options.SignIn.RequireConfirmedAccount = false;
                options.User.RequireUniqueEmail = true;
            })
                .AddDefaultUI()
                .AddRoles<ApplicationRole>()
                .AddRoleManager <RoleManager<ApplicationRole>>()
                .AddEntityFrameworkStores<ADProjContext>()
                .AddDefaultTokenProviders();

            services.AddControllersWithViews()
                .AddRazorRuntimeCompilation();


            //This DI cannot use singleton because it couldnt scope another DI DBContext
            services.AddScoped<IRecipeService, RecipeService>();
            services.AddScoped<IUserService, UserService>();
            services.AddScoped<IGroupService, GroupService>();

            // This is to handle reference loop situation when returning Json from async method
            // in API controller
            services.AddControllersWithViews()
                        .AddJsonOptions(o => o.JsonSerializerOptions
                        .ReferenceHandler = ReferenceHandler.Preserve);

            /*            services.AddCors(o => o.AddPolicy("ReactPolicy", builder =>
                        {
                            builder.AllowAnyOrigin()
                                   .AllowAnyMethod()
                                   .AllowAnyHeader()
                            //   .AllowCredentials()
                            ;
                        }));*/

            //   services.AddDbContext<ADProjContext>
            //   (o => o.UseSqlServer(Configuration.
            //   GetConnectionString(Environment.GetEnvironmentVariable("Server=DESKTOP-00OV8A0;Database=Project;Integrated Security=true;"))));
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env, ADProjContext db, UserManager<ApplicationUser> um)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
                app.UseMigrationsEndPoint();
            }
            else
            {
                app.UseExceptionHandler("/Home/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }

            app.UseCors("ReactPolicy");

            db.Database.EnsureDeleted();
            db.Database.EnsureCreated();
            new DbSeedData(db, um).Init();

            app.UseHttpsRedirection();
            app.UseStaticFiles();
            // https://docs.microsoft.com/en-us/aspnet/core/fundamentals/static-files?view=aspnetcore-5.0
            /*            app.UseStaticFiles(new StaticFileOptions
                        {
                            FileProvider = new PhysicalFileProvider(Path.Combine(env.ContentRootPath, "RecipesImage")),
                            RequestPath = "/RecipesImage"
                        });*/

            app.UseRouting();

            app.UseAuthentication();
            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllerRoute(
                    name: "default",
                    pattern: "{controller=Home}/{action=Index}/{id?}");
                endpoints.MapRazorPages();
            });
        }
    }
}
