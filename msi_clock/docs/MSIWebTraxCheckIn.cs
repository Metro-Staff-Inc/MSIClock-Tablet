using System;
using System.Web;
using System.Collections;
using System.Web.Services;
using System.Web.Security;
using System.Security.Principal;
using System.Web.Services.Protocols;
using MSI.Web.MSINet.BusinessEntities;
using MSI.Web.MSINet.BusinessLogic;
using MSI.Web.MSINet.Common;
using System.IO;
//using MSIToolkit.Logging;

namespace MSI.Web.Services
{
    public class UserCredentials : SoapHeader
    {
        public string UserName;
        public string PWD;
    }
    /// <summary>
    /// Summary description for MSIWebTraxCheckIn
    /// </summary>
    [WebService(Namespace = "http://msiwebtrax.com/")]
    [WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
    public class MSIWebTraxCheckIn : System.Web.Services.WebService
    {

        //PerformanceLogger log = new PerformanceLogger("AdoNetAppender");
        public UserCredentials CredentialsHeader;
        private decimal _totalHours = 0M;

        public MSIWebTraxCheckIn()
        {
            //Uncomment the following line if using designed components 
            //InitializeComponent(); 
        }

        [WebMethod]
        [SoapHeader("CredentialsHeader")]
        public RecordSwipeReturn RecordSwipe(string swipeInput)
        {
            //log.Info("RecordSwipe", swipeInput);
            HttpRequest req = Context.Request;
            Uri uri = req.Url;
            RecordSwipeReturn returnVal = new RecordSwipeReturn();

            bool isValid = false;

            if (swipeInput != null && swipeInput.Length > 0)
            {
                //validate the credentials
                //validate the password
                if (Membership.ValidateUser(CredentialsHeader.UserName, CredentialsHeader.PWD))
                {
                    GenericPrincipal userPrincipal = new GenericPrincipal(new GenericIdentity(CredentialsHeader.UserName), null);

                    //get the client id from the user name
                    ClientBL clientBL = new ClientBL();
                    Client client = clientBL.GetClientByUserName(CredentialsHeader.UserName);

                    if (client.ClientID > 0)
                    {
                        string[] inputParms = swipeInput.Split(new string[] { "|*|" }, StringSplitOptions.None);
                        string badgeNumber = String.Empty;
                        int clientLocation = 0;
                        DateTime punchDateTime = new DateTime(1, 1, 1);
                        if (inputParms != null && inputParms.Length > 0)
                        {

                            if (inputParms.Length >= 2)
                            {
                                //get the badge number
                                badgeNumber = inputParms[0];
                                //get the punch date/time
                                try
                                {
                                    punchDateTime = DateTime.Parse(inputParms[1]);
                                    isValid = true;
                                }
                                catch (Exception dateEx)
                                {
                                    //ERROR: invalid date
                                    returnVal.SystemErrorCode = "-6";
                                }
                                if(inputParms.Length == 3)
                                {
                                    isValid = false;
                                    try
                                    {
                                        clientLocation = Convert.ToInt32(inputParms[2]);
                                        isValid = true;
                                    }
                                    catch(Exception ex)
                                    {
                                        returnVal.SystemErrorCode = "-7";
                                    }
                                }

                                if (isValid)
                                {
                                    //record the swipe
                                    EmployeePunchSummary punchInfo = new EmployeePunchSummary();
                                    punchInfo.ClientID = client.ClientID;
                                    punchInfo.TempNumber = badgeNumber;
                                    punchInfo.PunchDateTime = punchDateTime;
                                    punchInfo.Location = clientLocation;
                                    HelperFunctions helper = new HelperFunctions();
                                    punchInfo.RoundedPunchDateTime = helper.GetRoundedPunchTime(punchDateTime);
                                    punchInfo.ManualOverride = false;
                                    EmployeePunchBL employeePunchBL = new EmployeePunchBL();
                                    EmployeePunchResult result = employeePunchBL.RecordEmployeePunch(punchInfo, userPrincipal);
                                    returnVal.PunchSuccess = result.PunchSuccess;
                                    returnVal.PunchType = result.PunchType.ToString();
                                    returnVal.PunchException = result.PunchException;
                                    returnVal.FirstName = result.EmployeePunchSummaryInfo.EmployeeFirstName;
                                    returnVal.LastName = result.EmployeePunchSummaryInfo.EmployeeLastName;
                                    _totalHours = result.EmployeePunchSummaryInfo.CurrentWeeklyHours;
                                }
                            }
                            else
                            {
                                //ERROR too few input parameters
                                returnVal.SystemErrorCode = "-5";
                            }
                        }
                        else
                        {
                            //ERROR:invalid input parameter format
                            returnVal.SystemErrorCode = "-4";
                        }
                    }
                    else
                    {
                        //ERROR: client not authorized to use check in
                        returnVal.SystemErrorCode = "-3";
                    }
                }
            }
            else
            {
                //ERROR input parameters not found
                returnVal.SystemErrorCode = "-2";
            }
            //log.Info("RecordSwipe", "Return val: " + returnVal.SystemErrorCode);
            return returnVal;
        }

        [WebMethod]
        [SoapHeader("CredentialsHeader")]
        public RecordSwipeReturn RecordSwipeBiometric(string swipeInput)
        {
            //log.Info("RecordSwipeBiometric", swipeInput);
            RecordSwipeReturn returnVal = new RecordSwipeReturn();
            HttpRequest req = Context.Request;
            Uri uri = req.Url;

            //return values
            //System Error Codes
            //-1:connection not secure
            //-2:input parameters not found
            //-3:client not authorized
            //-4:invalid input parameter format
            //-5:too few input parameters
            //-6:invalid date

            //if (Context.Request.IsSecureConnection)
            //{
            bool isValid = false;

            if (swipeInput != null && swipeInput.Length > 0)
            {
                //validate the credentials
                //validate the password
                if (Membership.ValidateUser(CredentialsHeader.UserName, CredentialsHeader.PWD))
                {
                    GenericPrincipal userPrincipal = new GenericPrincipal(new GenericIdentity(CredentialsHeader.UserName), null);

                    //get the client id from the user name
                    ClientBL clientBL = new ClientBL();
                    Client client = clientBL.GetClientByUserName(CredentialsHeader.UserName);
                    ClientPreferences clientPrefs = clientBL.GetClientPreferencesByID(client.ClientID);

                    if (client.ClientID > 0)
                    {
                        string[] inputParms = swipeInput.Split(new string[] { "|*|" }, StringSplitOptions.None);
                        string badgeNumber = String.Empty;
                        DateTime punchDateTime = new DateTime(1, 1, 1);
                        int biometricSuccess = 0;
                        if (inputParms != null && inputParms.Length > 0)
                        {
                            if (inputParms.Length == 3)
                            {
                                //get the badge number
                                badgeNumber = inputParms[0];
                                //if(BadgeNumber.Contains("00700"))
                                //{
                                //    System.Threading.Thread.Sleep(30000);
                                //}
                                //get the punch date/time
                                try
                                {
                                    punchDateTime = DateTime.Parse(inputParms[1]);
                                    biometricSuccess = Int32.Parse(inputParms[2]);
                                    isValid = true;
                                }
                                catch (Exception dateEx)
                                {
                                    //ERROR: invalid date or bio flag
                                    returnVal.SystemErrorCode = "-6";
                                }

                                if (isValid)
                                {
                                    //record the swipe
                                    EmployeePunchSummary punchInfo = new EmployeePunchSummary();
                                    punchInfo.ClientID = client.ClientID;
                                    punchInfo.UseExactTimes = clientPrefs.UseExactTimes;
                                    punchInfo.TempNumber = badgeNumber;
                                    punchInfo.PunchDateTime = punchDateTime;
                                    //punchInfo.PunchDateTime = new DateTime(2016, 9, 01, 14, 59, 58);
                                    punchInfo.BiometricResult = biometricSuccess;
                                    HelperFunctions helper = new HelperFunctions();
                                    if (client.ClientID >= 325 && client.ClientID <= 327)
                                    {
                                        punchInfo.RoundedPunchDateTime = helper.GetExact15PunchTime(punchInfo.PunchDateTime);
                                    }
                                    else
                                    {
                                        if (!clientPrefs.UseExactTimes)
                                        {
                                            punchInfo.RoundedPunchDateTime = helper.GetRoundedPunchTime(punchInfo.PunchDateTime);
                                        }
                                        else
                                        {
                                            punchInfo.RoundedPunchDateTime = punchInfo.PunchDateTime;
                                        }
                                    }
                                    punchInfo.ManualOverride = false;
                                    EmployeePunchBL employeePunchBL = new EmployeePunchBL();
                                    EmployeePunchResult result = employeePunchBL.RecordEmployeePunch(punchInfo, userPrincipal);

                                    returnVal.PunchSuccess = result.PunchSuccess;
                                    returnVal.PunchType = result.PunchType.ToString();
                                    returnVal.PunchException = result.PunchException;
                                    returnVal.FirstName = result.EmployeePunchSummaryInfo.EmployeeFirstName;
                                    returnVal.LastName = result.EmployeePunchSummaryInfo.EmployeeLastName;
                                    _totalHours = result.EmployeePunchSummaryInfo.CurrentWeeklyHours;
                                }
                            }
                            else
                            {
                                //ERROR too few input parameters
                                returnVal.SystemErrorCode = "-5";
                            }
                        }
                        else
                        {
                            //ERROR:invalid input parameter format
                            returnVal.SystemErrorCode = "-4";
                        }
                    }
                    else
                    {
                        //ERROR: client not authorized to use check in
                        returnVal.SystemErrorCode = "-3";
                    }
                }
            }
            else
            {
                //ERROR input parameters not found
                returnVal.SystemErrorCode = "-2";
            }
            //}
            //else
            //{
            //ERROR Connection not secure
            //    returnVal.SystemErrorCode = "-1";
            // }
            //System.Threading.Thread.Sleep(70000);
            //log.Info("RecordSwipeBiometric", "Return val: " + returnVal.SystemErrorCode);
            return returnVal;
        }

        [WebMethod]
        [SoapHeader("CredentialsHeader")]
        public RecordSwipeReturn RecordSwipeDepartmentOverride(string swipeInput)
        {
            //log.Info("RecordSwipeDepartmentOverride", swipeInput);
            RecordSwipeReturn returnVal = new RecordSwipeReturn();

            //return values
            //System Error Codes
            //-1:connection not secure
            //-2:input parameters not found
            //-3:client not authorized
            //-4:invalid input parameter format
            //-5:too few input parameters
            //-6:invalid date

            //if (Context.Request.IsSecureConnection)
            //{
            bool isValid = false;
            HttpRequest req = Context.Request;
            Uri uri = req.Url;

            if (swipeInput != null && swipeInput.Length > 0)
            {
                //validate the credentials
                //validate the password
                if (Membership.ValidateUser(CredentialsHeader.UserName, CredentialsHeader.PWD))
                {
                    GenericPrincipal userPrincipal = new GenericPrincipal(new GenericIdentity(CredentialsHeader.UserName), null);

                    //get the client id from the user name
                    ClientBL clientBL = new ClientBL();
                    Client client = clientBL.GetClientByUserName(CredentialsHeader.UserName);
                    //ClientPreferences clientPrefs = clientBL.GetClientPreferencesByID(client.ClientID);

                    if (client.ClientID > 0)
                    {
                        string[] inputParms = swipeInput.Split(new string[] { "|*|" }, StringSplitOptions.None);
                        string badgeNumber = String.Empty;
                        DateTime punchDateTime = new DateTime(1, 1, 1);
                        int deptOverride = 0;
                        if (inputParms != null && inputParms.Length > 0)
                        {
                            if (inputParms.Length == 3)
                            {
                                //get the badge number
                                badgeNumber = inputParms[0];
                                //get the punch date/time
                                try
                                {
                                    punchDateTime = DateTime.Parse(inputParms[1]);
                                    deptOverride = Int32.Parse(inputParms[2]);
                                    isValid = true;
                                }
                                catch (Exception dateEx)
                                {
                                    //ERROR: invalid date or bio flag
                                    returnVal.SystemErrorCode = "-6";
                                }

                                if (isValid)
                                {
                                    //record the swipe
                                    EmployeePunchSummary punchInfo = new EmployeePunchSummary();
                                    punchInfo.ClientID = client.ClientID;
                                    punchInfo.TempNumber = badgeNumber;
                                    punchInfo.PunchDateTime = punchDateTime;
                                    punchInfo.DeptOverride = deptOverride;
                                    HelperFunctions helper = new HelperFunctions();
                                    punchInfo.RoundedPunchDateTime = helper.GetRoundedPunchTime(punchDateTime);
                                    punchInfo.ManualOverride = false;
                                    EmployeePunchBL employeePunchBL = new EmployeePunchBL();
                                    EmployeePunchResult result = employeePunchBL.RecordEmployeePunchDepartmentOverride(punchInfo, userPrincipal);

                                    returnVal.PunchSuccess = result.PunchSuccess;
                                    returnVal.PunchType = result.PunchType.ToString();
                                    returnVal.PunchException = result.PunchException;
                                    returnVal.FirstName = result.EmployeePunchSummaryInfo.EmployeeFirstName;
                                    returnVal.LastName = result.EmployeePunchSummaryInfo.EmployeeLastName;
                                    _totalHours = result.EmployeePunchSummaryInfo.CurrentWeeklyHours;
                                }
                            }
                            else
                            {
                                //ERROR too few input parameters
                                returnVal.SystemErrorCode = "-5";
                            }
                        }
                        else
                        {
                            //ERROR:invalid input parameter format
                            returnVal.SystemErrorCode = "-4";
                        }
                    }
                    else
                    {
                        //ERROR: client not authorized to use check in
                        returnVal.SystemErrorCode = "-3";
                    }
                }
            }
            else
            {
                //ERROR input parameters not found
                returnVal.SystemErrorCode = "-2";
            }
            //}
            //else
            //{
            //ERROR Connection not secure
            //    returnVal.SystemErrorCode = "-1";
            // }
            //System.Threading.Thread.Sleep(70000);
            //log.Info("RecordSwipeBiometric", "Return val: " + returnVal.SystemErrorCode);
            return returnVal;
        }

        private string filePath = HttpContext.Current.Server.MapPath("..\\Dropbox\\Images\\");

        [WebMethod]
        [SoapHeader("CredentialsHeader")]
        public string SaveImage(string fileName, byte[] data, string dir)
        {
            //log.Info("SaveImage", fileName);
            filePath += dir;
            string file = Path.Combine(filePath, Path.GetFileName(fileName));
            try
            {
                using (FileStream fs = new FileStream(file, FileMode.Create))
                {
                    fs.Write(data, 0, (int)data.Length);
                }
            }
            catch (Exception e) {
                //Console.WriteLine(e);
            }
            String resp = data.Length + " bytes written to file - " + file.ToString();
            //log.Info("SaveImage", resp);
            return resp;
        }
    }
}
