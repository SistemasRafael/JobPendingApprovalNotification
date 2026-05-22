codeunit 50149 "JobNotificationPendingApproval"
{
    trigger OnRun()
    var
        ApprovalEntry: Record "Approval Entry";
        LastUser: Code[50];
        PendingCount: Integer;
        CompanyRec: Record Company;
        PendingApprovalsByUser: JsonArray;
        CompanyArray: JsonArray;
        JsonText: Text;

    begin
        CompanyRec.SetFilter(Name, '<>%1', 'CENTRAL');

        if CompanyRec.FindSet() then begin
            Clear(PendingApprovalsByUser);
            repeat
                ApprovalEntry.ChangeCompany(CompanyRec.Name);
                ApprovalEntry.SetRange(Status, ApprovalEntry.Status::Open);
                ApprovalEntry.SetCurrentKey("Approver ID");

                if ApprovalEntry.FindSet() then begin
                    LastUser := '';
                    PendingCount := 0;

                    repeat
                        if LastUser <> ApprovalEntry."Approver ID" then begin
                            if (LastUser <> '') and (PendingCount > 0) then begin
                                Clear(CompanyArray);
                                CompanyArray.Add(GetCompanyObject(CompanyRec.Name, PendingCount));

                                if not UserExistsInArray(PendingApprovalsByUser, LastUser) then begin
                                    PendingApprovalsByUser.Add(GetUserObject(LastUser, CompanyArray));
                                end else begin
                                    AddCompanyToUser(PendingApprovalsByUser, LastUser, CompanyRec.Name, PendingCount);
                                end;
                            end;

                            // reset for new user
                            LastUser := ApprovalEntry."Approver ID";
                            PendingCount := 0;
                        end;

                        PendingCount += 1;
                    until ApprovalEntry.Next() = 0;
                end;
            until CompanyRec.Next() = 0;

            SendPendingApprovals(PendingApprovalsByUser);
        end;
    end;

    local procedure SendPendingApprovals(PendingApprovals: JsonArray)
    var
        index: Integer;
        indexCompanies: Integer;
        CurrentUserObj: JsonObject;
        CurrentUserCompaniesObject: JsonArray;
        CurrentUser: JsonToken;
        CurrentUserCompanies: JsonToken;
        CurrentCompanies: JsonToken;
        CurrentCompanyObj: JsonObject;
        UserValue: JsonToken;
        CompanyValue: JsonToken;
        ApprovalPendingValue: JsonToken;
        UserName: Text;
        Company: Text;
        ApprovalPending: Integer;

        BodyText: Text;
    begin
        for index := 0 to PendingApprovals.Count() - 1 do begin
            BodyText := '';
            PendingApprovals.Get(index, CurrentUser);
            CurrentUserObj := CurrentUser.AsObject();
            CurrentUserObj.Get('User', UserValue);
            CurrentUserObj.Get('companies', CurrentUserCompanies);
            UserName := UserValue.AsValue().AsText();
            CurrentUserCompaniesObject := CurrentUserCompanies.AsArray();

            for indexCompanies := 0 to CurrentUserCompaniesObject.Count() - 1 do begin
                CurrentUserCompaniesObject.Get(indexCompanies, CurrentCompanies);
                CurrentCompanyObj := CurrentCompanies.AsObject();
                CurrentCompanyObj.Get('Company', CompanyValue);
                CurrentCompanyObj.Get('ApprovalPending', ApprovalPendingValue);
                Company := CompanyValue.AsValue().AsText();
                ApprovalPending := ApprovalPendingValue.AsValue().AsInteger();

                if ApprovalPending > 1 then begin
                    BodyText += StrSubstNo('<li>There are <strong>%2</strong> pending approvals in <strong>%1</strong></li>',
                                            Company,
                                            ApprovalPending);
                end else begin
                    BodyText += StrSubstNo('<li>There is <strong>%2</strong> pending approval in <strong>%1</strong></li>',
                                            Company,
                                            ApprovalPending);
                end;
            end;

            SendNotification(UserName, BodyText);
        end;
    end;

    local procedure SendNotification(UserName: Text; BodyLines: Text)
    var
        UserRec: Record User;
        Email: Codeunit Email;
        EmailMessage: Codeunit "Email Message";
        EmailTo: Text;
        BodyText: Text;
    begin
        UserRec.SetRange("User Name", UserName);

        if not UserRec.FindFirst() then begin
            exit;
        end;

        EmailTo := UserRec."Contact Email";

        if EmailTo = '' then begin
            exit;
        end;

        BodyText :=
            '<html><body>' +
            '<h3>You have pending approvals</h3>' +
            '<ul>' + BodyLines + '</ul>' +
            '<p>Please review them in Business Central.</p>' +
            '</body></html>';

        EmailMessage.Create(
            'rafael.flores@heliostarmetals.com',
            //EmailTo,
            'Pending Approvals Reminder',
            BodyText,
            true
        );

        Email.Send(EmailMessage, Enum::"Email Scenario"::Notification);
    end;

    local procedure AddCompanyToUser(ApprovalPendingByUser: JsonArray;
                                    UserName: Text;
                                    CompanyName: Text;
                                    PendingCount: Integer)
    var
        index: Integer;
        TokenUserObject: JsonToken;
        TokenUserValue: JsonToken;
        UserObj: JsonObject;
        TokenCompanies: JsonToken;
        CompanyArr: JsonArray;
        ExistingUser: Text;
    begin
        for index := 0 to ApprovalPendingByUser.Count() - 1 do begin
            ApprovalPendingByUser.Get(index, TokenUserObject);
            UserObj := TokenUserObject.AsObject();
            UserObj.Get('User', TokenUserValue);
            ExistingUser := TokenUserValue.AsValue().AsText();

            if ExistingUser = UserName then begin
                UserObj.Get('companies', TokenCompanies);
                CompanyArr := TokenCompanies.AsArray();
                CompanyArr.Add(GetCompanyObject(CompanyName, PendingCount));
                UserObj.Replace('companies', CompanyArr);
                exit;
            end;
        end;
    end;

    local procedure UserExistsInArray(ApprovalPendingByUser: JsonArray;
                                    UserName: Text): Boolean
    var
        index: Integer;
        TokenUserObject: JsonToken;
        TokenUserValue: JsonToken;
        UserObj: JsonObject;
        ExistingUser: Text;
    begin
        for index := 0 to ApprovalPendingByUser.Count() - 1 do begin
            ApprovalPendingByUser.Get(index, TokenUserObject);
            UserObj := TokenUserObject.AsObject();
            UserObj.Get('User', TokenUserValue);
            ExistingUser := TokenUserValue.AsValue().AsText();

            if ExistingUser = UserName then begin
                exit(true);
            end;
        end;

        exit(false);
    end;


    local procedure GetCompanyObject(Company: Text; PendingApprovals: Integer): JsonObject
    var
        CompanyObject: JsonObject;
    begin
        Clear(CompanyObject);
        CompanyObject.Add('Company', Company);
        CompanyObject.Add('ApprovalPending', PendingApprovals);

        exit(CompanyObject);
    end;

    local procedure GetUserObject(UserName: Text; CompanyArray: JsonArray): JsonObject
    var
        UserObject: JsonObject;
    begin
        Clear(UserObject);
        UserObject.Add('User', UserName);
        UserObject.Add('companies', CompanyArray);

        exit(UserObject);
    end;

    local procedure AddJobLog(Description: Text)
    var
        ApprovalEntry: Record "Approval Entry";
        JobQueueEntry: Record "LogNotificationPendingApproval";
        UserRec: Record User;
    begin
        Clear(JobQueueEntry);
        JobQueueEntry.Init();
        JobQueueEntry."Description" := Description;
        JobQueueEntry."Date and Time" := CurrentDateTime();
        JobQueueEntry.Insert(true);
    end;
}