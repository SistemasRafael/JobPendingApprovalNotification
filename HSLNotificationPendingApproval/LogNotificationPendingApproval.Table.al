table 50149 "LogNotificationPendingApproval"
{
    Caption = 'Log Notification Pending Approval';

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Description"; Text[2048])
        {
            Caption = 'Description';
        }

        field(3; "Date and Time"; DateTime)
        {
            Caption = 'Date and Time';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}