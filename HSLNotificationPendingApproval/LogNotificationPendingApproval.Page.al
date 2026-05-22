page 50149 "Notification Pending Approval"
{
    Caption = 'Notification Pending Approval';
    PageType = List;
    Editable = false;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "LogNotificationPendingApproval";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Entry No."; Rec."Entry No.")
                {
                }
                field("Description"; Rec."Description")
                {
                }
                field("Date and Time"; Rec."Date and Time")
                {
                }
            }
        }
    }
}