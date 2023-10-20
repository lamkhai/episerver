using EPiServer.Shell.Security;
using Microsoft.AspNetCore.Identity;
using System.ComponentModel.DataAnnotations.Schema;

namespace CMS.Models.Entities;

public class CustomUser : IdentityUser, IUIUser
{
    public string Comment { get; set; }
    public bool IsApproved { get; set; }
    public bool IsLockedOut { get; set; }

    [Column(TypeName = "datetime2")]
    public DateTime CreationDate { get; set; }

    [Column(TypeName = "datetime2")]
    public DateTime? LastLockoutDate { get; set; }

    [Column(TypeName = "datetime2")]
    public DateTime? LastLoginDate { get; set; }

    public string PasswordQuestion { get; }

    public string ProviderName
    {
        get { return "MyProviderName"; }
    }

    [NotMapped]
    public string Username
    {
        get { return base.UserName; }
        set { base.UserName = value; }
    }
}