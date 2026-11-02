using System.Data;
using System.Reflection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using SmartFoundation.Application.Services;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Models;
using SmartFoundation.DataEngine.Core.Services;

namespace SmartFoundation.Application.Tests.Services;

public class ResultSetSchemaTests
{
    [Theory]
    [InlineData("Crud", false)]
    [InlineData("DataLoad", false)]
    [InlineData("ExtraDataLoad", false)]
    [InlineData("Crud", true)]
    [InlineData("DataLoad", true)]
    [InlineData("ExtraDataLoad", true)]
    public async Task MixedResults_PreserveSchemaRowsAndOrder(string operation, bool populated)
    {
        var first = new DataTable();
        first.Columns.Add("permissionTypeName_E", typeof(string));
        first.Rows.Add("View");
        var empty = new DataTable();
        empty.Columns.Add("residentInfoID", typeof(long));
        var lookup = new DataTable();
        lookup.Columns.Add("billPaymentTypeID", typeof(int));
        lookup.Columns.Add("billPaymentTypeName_A", typeof(string));
        if (populated) lookup.Rows.Add(7, "Payment");
        var last = new DataTable();
        last.Columns.Add("IsSuccessful", typeof(int));
        last.Columns.Add("Message_", typeof(string));
        last.Rows.Add(1, DBNull.Value);

        var response = await ReadAsync(first, empty, lookup, last);
        Assert.Equal(4, response.Datasets.Count);
        Assert.Equal(4, response.DatasetSchemas.Count);
        Assert.Empty(response.Datasets[1]);
        Assert.Equal(new[] { "residentInfoID" }, response.DatasetSchemas[1]);
        Assert.Null(response.Datasets[3][0]["Message_"]);

        var engine = new Mock<ISmartComponentService>();
        engine.Setup(x => x.ExecuteAsync(It.IsAny<SmartRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(response);
        var service = new MastersServies(engine.Object, NullLogger<MastersServies>.Instance);
        var parameters = new Dictionary<string, object?> { ["pageName_"] = "SchemaTest" };
        var result = operation switch
        {
            "Crud" => await service.GetCrudDataSetAsync(parameters),
            "DataLoad" => await service.GetDataLoadDataSetAsync(parameters),
            _ => await service.GetExtraDataLoadDataSetAsync(parameters)
        };

        Assert.Equal(4, result.Tables.Count);
        for (var i = 0; i < result.Tables.Count; i++)
        {
            Assert.Equal($"Table{i}", result.Tables[i].TableName);
            Assert.Equal(response.DatasetSchemas[i],
                result.Tables[i].Columns.Cast<DataColumn>().Select(c => c.ColumnName));
            Assert.Equal(response.Datasets[i].Count, result.Tables[i].Rows.Count);
        }
        Assert.Equal("View", result.Tables[0].Rows[0]["permissionTypeName_E"]);
        Assert.Equal(DBNull.Value, result.Tables[3].Rows[0]["Message_"]);
        Assert.All(result.Tables[2].Columns.Cast<DataColumn>(), c => Assert.Equal(typeof(object), c.DataType));

        // Same column checks and row iteration used by MVC ReadOptions.
        var options = ReadOptions(result, 2, "billPaymentTypeName_A", "billPaymentTypeID");
        Assert.Equal(populated ? new[] { ("Payment", "7") } : Array.Empty<(string, string)>(), options);
        engine.Verify(x => x.ExecuteAsync(It.IsAny<SmartRequest>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task SingleResult_PreservesSchemaEvenWithoutRows(bool populated)
    {
        var table = new DataTable();
        table.Columns.Add("Id", typeof(int));
        table.Columns.Add("Name", typeof(string));
        if (populated) table.Rows.Add(3, "Test");
        var response = await ReadAsync(table);
        Assert.Single(response.Datasets);
        Assert.Single(response.DatasetSchemas);
        Assert.Equal(new[] { "Id", "Name" }, response.DatasetSchemas[0]);
        Assert.Equal(populated ? 1 : 0, response.Datasets[0].Count);
        if (populated) Assert.Equal(3, response.Datasets[0][0]["Id"]);
    }

    [Fact]
    public async Task LegacyResponseWithoutSchema_StillConvertsNonEmptyRows()
    {
        var response = new SmartResponse
        {
            Success = true,
            Datasets = [[new() { ["Id"] = 4, ["Name"] = null }], []]
        };
        var engine = new Mock<ISmartComponentService>();
        engine.Setup(x => x.ExecuteAsync(It.IsAny<SmartRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(response);
        var service = new MastersServies(engine.Object, NullLogger<MastersServies>.Instance);
        var ds = await service.GetDataLoadDataSetAsync(new Dictionary<string, object?>());
        Assert.Equal(2, ds.Tables.Count);
        Assert.Equal(4, ds.Tables[0].Rows[0]["Id"]);
        Assert.Equal(DBNull.Value, ds.Tables[0].Rows[0]["Name"]);
        Assert.Empty(ds.Tables[1].Columns.Cast<DataColumn>());
    }

    private static async Task<SmartResponse> ReadAsync(params DataTable[] tables)
    {
        using var reader = new DataTableReader(tables);
        var response = new SmartResponse { Success = true };
        var method = typeof(SmartComponentService).GetMethod(
            "ReadResultSetsAsync", BindingFlags.Static | BindingFlags.NonPublic)!;
        await (Task)method.Invoke(null, new object[] { reader, response, CancellationToken.None })!;
        return response;
    }

    private static List<(string, string)> ReadOptions(DataSet source, int index, string text, string value)
    {
        if (index < 0 || index >= source.Tables.Count)
            throw new InvalidOperationException("DDL table index not found.");
        var table = source.Tables[index];
        if (!table.Columns.Contains(text) || !table.Columns.Contains(value))
            throw new InvalidOperationException("DDL columns mismatch.");
        return table.Rows.Cast<DataRow>()
            .Select(r => (r[text].ToString()!, r[value].ToString()!)).ToList();
    }
}
