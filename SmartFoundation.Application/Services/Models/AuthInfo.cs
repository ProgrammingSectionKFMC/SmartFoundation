using static System.Collections.Specialized.BitVector32;

namespace SmartFoundation.Application.Services.Models;

/// <summary>
/// Authentication result parsed from the login stored procedure.
/// </summary>
/// 

public sealed record AuthInfo(

    int usersActive,                  // 0=Error, 1=Success, 2=Warning, 3=Info
    string? Message_,
    string? usersId,
    string? fullName,
    string? OrganizationID,
    string? OrganizationName,
    string? IdaraID,
    string? IdaraName,
    string? DepartmentID,
    string? DepartmentName,
    string? SectionID,
    string? SectionName,
    string? DivisonID,
    string? DivisonName,
    string? photoBase64,
    string? ThameName,
    string? DeptCode,
    string? nationalID,
    string? GeneralNo,
    string? AdminTypeID,
    string? AdminTypeName

    );