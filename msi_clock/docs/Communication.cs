using System;
using FingerprintVerification.MSIWebTraxCheckIn;
using FingerprintVerification.MSIWebTraxCheckInSummary;
using System.Drawing;
using System.Net;

namespace FingerprintVerification
{
    public class CommunicationReturnInfo
    {
        public static string infoEng;
        public static string infoSpan;
        public static Color col;
        public static int swipeResult;
        public static Exception exception;
        public static decimal hoursWorked;
        public static bool checkIn;
    }

    public delegate void MyEventHandler();
    
    public partial class Communication
    {

        public static event MyEventHandler signInComplete;

        public static bool keepAliveFirstTime = true;
        public static bool returnValue = true;
        public static MSIWebTraxCheckInSummary.RecordSwipeReturnSummary punchReturn;

        public static void SignInWithSummary(object efIn)
        {
            EntryForm ef = (EntryForm)efIn;
            returnValue = true;
            int deptOverride = 0;
            for (int i = 0; i < ef.EnvInfo.DepartmentIDs.Count; i++ )
            {
                if (ef.EnvInfo.DepartmentButtons[i].Checked )
                {
                    deptOverride = ef.EnvInfo.DepartmentIDs[i];
                }
            }
            deptOverride = ef.EnvInfo.DepartmentID;
            ef.setDefaultDepartment(0);
            if (ef.EnvInfo.MultipleClients)
            {
                SignInWithSummaryMultipleClients(ef);
                return;
            }
            MSIWebTraxCheckInSummarySoapClient clientChkInSummary = new MSIWebTraxCheckInSummarySoapClient("MSIWebTraxCheckInSummarySoap");
            MSIWebTraxCheckInSummary.UserCredentials uc = new MSIWebTraxCheckInSummary.UserCredentials();
            uc.PWD = ef.EnvInfo.Password[0];
            uc.UserName = ef.EnvInfo.UserId[0];
            try
            {
                ef.EnvInfo.PunchInProgress++;
                if( deptOverride == 0 )
                {
                    punchReturn = clientChkInSummary.RecordSwipeSummary(uc, ef.EmpInf.IdNum + "|*|" +
                        ef.EmpInf.PunchDt.ToString());
                }
                else
                {
                    punchReturn = clientChkInSummary.RecordSwipeSummaryDepartmentOverride(uc, ef.EmpInf.IdNum + "|*|" +
                        ef.EmpInf.PunchDt.ToString() + "|*|" + deptOverride );
                }
                string hours = punchReturn.CurrentWeeklyHours.ToString() + " hrs.";
                string name = punchReturn.RecordSwipeReturnInfo.LastName + ", " + punchReturn.RecordSwipeReturnInfo.FirstName;
                if (name.Length > ef.EnvInfo.NameSize)
                    name = name.Substring(0, ef.EnvInfo.NameSize);
                ef.setDefaultDepartment(0);  //reset to default department if necessary...
                switch (punchReturn.RecordSwipeReturnInfo.PunchType.ToLower())
                {
                    case "checkin":
                        CommunicationReturnInfo.infoEng = "Enter " + name + ": " + hours;
                        CommunicationReturnInfo.infoSpan = "Entrada " + name + ": " + hours;
                        CommunicationReturnInfo.col = Color.Green;
                        CommunicationReturnInfo.swipeResult = 0;
                        CommunicationReturnInfo.hoursWorked = punchReturn.CurrentWeeklyHours;
                        CommunicationReturnInfo.checkIn = true;
                        break;
                    case "checkout":
                        CommunicationReturnInfo.infoEng = "Goodbye " + name + ": " + hours;
                        CommunicationReturnInfo.infoSpan = "Adios " + name + ": " + hours;
                        CommunicationReturnInfo.col = Color.Green;
                        CommunicationReturnInfo.swipeResult = 0;
                        CommunicationReturnInfo.checkIn = false;
                        break;
                    default:
                        CommunicationReturnInfo.hoursWorked = punchReturn.CurrentWeeklyHours;
                        CommunicationReturnInfo.checkIn = false;
                        if (punchReturn.RecordSwipeReturnInfo.PunchException == 2)
                        {
                            //not authorized
                            CommunicationReturnInfo.infoEng = "Not Authorized";
                            CommunicationReturnInfo.infoSpan = "No Authorizado";
                            CommunicationReturnInfo.col = Color.Red;
                            CommunicationReturnInfo.swipeResult = punchReturn.RecordSwipeReturnInfo.PunchException;
                        }
                        else if (punchReturn.RecordSwipeReturnInfo.PunchException == 1)
                        {
                            //shift not started!!
                            CommunicationReturnInfo.infoEng = "Shift not yet started";
                            CommunicationReturnInfo.infoSpan = "Trabajo no ha comenzado";
                            CommunicationReturnInfo.col = Color.Red;
                            CommunicationReturnInfo.swipeResult = punchReturn.RecordSwipeReturnInfo.PunchException;
                        }
                        else if (punchReturn.RecordSwipeReturnInfo.PunchException == 3)
                        {
                            //shift is over!!
                            CommunicationReturnInfo.infoEng = "Shift has finished";
                            CommunicationReturnInfo.infoSpan = "Trabajo está terminado";
                            CommunicationReturnInfo.col = Color.Red;
                            CommunicationReturnInfo.swipeResult = punchReturn.RecordSwipeReturnInfo.PunchException;
                        }
                        else
                        {
                            CommunicationReturnInfo.infoEng = "Not Authorized!";
                            CommunicationReturnInfo.infoSpan = "!No Authorizado!";
                            CommunicationReturnInfo.col = Color.Red;
                            CommunicationReturnInfo.swipeResult = punchReturn.RecordSwipeReturnInfo.PunchException;
                            //error  print punch exception
                        }
                        break;
                }
            }
            catch (System.Exception ioe)
            {
                returnValue = false;
                CommunicationReturnInfo.infoEng = "Punch Recorded!";
                CommunicationReturnInfo.infoSpan = "Gracias!";
                CommunicationReturnInfo.col = Color.Green;
                CommunicationReturnInfo.swipeResult = -99;
                CommunicationReturnInfo.exception = ioe;
                CommunicationReturnInfo.hoursWorked = 0;
            }
            finally
            {
                ef.EnvInfo.PunchInProgress--;
                if (ef.EnvInfo.PunchInProgress < 0)
                    ef.EnvInfo.PunchInProgress = 0;
                signInComplete();
            }
        }

        public static void SignInWithSummaryMultipleClients(object efIn)
        {
            EntryForm ef = (EntryForm)efIn;


            MSIWebTraxCheckInSummarySoapClient clientChkInSummary = new MSIWebTraxCheckInSummarySoapClient("MSIWebTraxCheckInSummarySoap");
            MSIWebTraxCheckInSummary.UserCredentials uc = new MSIWebTraxCheckInSummary.UserCredentials();
            bool validPunch = false;
            bool returnValue = true;

            for (int i = 0; i < ef.EnvInfo.Password.Count && !validPunch; i++)
            {
                try
                {
                    uc.PWD = ef.EnvInfo.Password[i];
                    uc.UserName = ef.EnvInfo.UserId[i];

                    ef.EnvInfo.PunchInProgress++;
                    punchReturn = clientChkInSummary.RecordSwipeSummary(uc, ef.EmpInf.IdNum + "|*|" +
                        ef.EmpInf.PunchDt.ToString());
                    string hours = punchReturn.CurrentWeeklyHours.ToString() + " hrs.";
                    string name = punchReturn.RecordSwipeReturnInfo.LastName + ", " + punchReturn.RecordSwipeReturnInfo.FirstName;
                    if (name.Length > ef.EnvInfo.NameSize)
                        name = name.Substring(0, ef.EnvInfo.NameSize);
                    switch (punchReturn.RecordSwipeReturnInfo.PunchType.ToLower())
                    {
                        case "checkin":
                            CommunicationReturnInfo.infoEng = "Enter " + name + ": " + hours;
                            CommunicationReturnInfo.infoSpan = "Entrada " + name + ": " + hours;
                            CommunicationReturnInfo.col = Color.Green;
                            CommunicationReturnInfo.swipeResult = 0;
                            CommunicationReturnInfo.hoursWorked = punchReturn.CurrentWeeklyHours;
                            CommunicationReturnInfo.checkIn = true;
                            i = ef.EnvInfo.Password.Count;
                            break;
                        case "checkout":
                            CommunicationReturnInfo.infoEng = "Goodbye " + name + ": " + hours;
                            CommunicationReturnInfo.infoSpan = "Adios " + name + ": " + hours;
                            CommunicationReturnInfo.col = Color.Green;
                            CommunicationReturnInfo.swipeResult = 0;
                            CommunicationReturnInfo.checkIn = false;
                            i = ef.EnvInfo.Password.Count;
                            break;
                        default:
                            if (i < ef.EnvInfo.Password.Count - 1)
                            {
                                break;
                            }
                            CommunicationReturnInfo.hoursWorked = punchReturn.CurrentWeeklyHours;
                            CommunicationReturnInfo.checkIn = false;
                            if (punchReturn.RecordSwipeReturnInfo.PunchException == 2)
                            {
                                //not authorized
                                CommunicationReturnInfo.infoEng = "Not Authorized";
                                CommunicationReturnInfo.infoSpan = "No Authorizado";
                                CommunicationReturnInfo.col = Color.Red;
                                CommunicationReturnInfo.swipeResult = punchReturn.RecordSwipeReturnInfo.PunchException;
                            }
                            else if (punchReturn.RecordSwipeReturnInfo.PunchException == 1)
                            {
                                //shift not started!!
                                CommunicationReturnInfo.infoEng = "Shift not yet started";
                                CommunicationReturnInfo.infoSpan = "Trabajo no ha comenzado";
                                CommunicationReturnInfo.col = Color.Red;
                                CommunicationReturnInfo.swipeResult = punchReturn.RecordSwipeReturnInfo.PunchException;
                            }
                            else if (punchReturn.RecordSwipeReturnInfo.PunchException == 3)
                            {
                                //shift is over!!
                                CommunicationReturnInfo.infoEng = "Shift has finished";
                                CommunicationReturnInfo.infoSpan = "Trabajo está terminado";
                                CommunicationReturnInfo.col = Color.Red;
                                CommunicationReturnInfo.swipeResult = punchReturn.RecordSwipeReturnInfo.PunchException;
                            }
                            else
                            {
                                CommunicationReturnInfo.infoEng = "Not Authorized!";
                                CommunicationReturnInfo.infoSpan = "!No Authorizado!";
                                CommunicationReturnInfo.col = Color.Red;
                                CommunicationReturnInfo.swipeResult = punchReturn.RecordSwipeReturnInfo.PunchException;
                                //error  print punch exception
                            }
                            break;
                    }
                }
                catch (System.Exception ioe)
                {
                    returnValue = false;
                    CommunicationReturnInfo.infoEng = "Punch Recorded!";
                    CommunicationReturnInfo.infoSpan = "Gracias!";
                    CommunicationReturnInfo.col = Color.Green;
                    CommunicationReturnInfo.swipeResult = -99;
                    CommunicationReturnInfo.exception = ioe;
                    CommunicationReturnInfo.hoursWorked = 0;
                    i = ef.EnvInfo.Password.Count;
                }
                finally
                {
                    ef.EnvInfo.PunchInProgress--;
                    if (ef.EnvInfo.PunchInProgress < 0)
                        ef.EnvInfo.PunchInProgress = 0;
                    if (i >= (ef.EnvInfo.Password.Count - 1) || returnValue == false)
                        signInComplete();
                }
            }
        }
        
        public static bool UploadPicture(EntryForm ef)
        {
            bool success = true;
            MSIWebTraxCheckInSoapClient clientChkIn = new MSIWebTraxCheckInSoapClient("MSIWebTraxCheckInSoap");
            MSIWebTraxCheckIn.UserCredentials uc = new MSIWebTraxCheckIn.UserCredentials();

            uc.PWD = ef.EnvInfo.Password[0];
            uc.UserName = ef.EnvInfo.UserId[0];

            try
            {
                clientChkIn.SaveImage(uc, ef.EmpInf.PicName, ef.EmpInf.PicData, ef.EnvInfo.Dir);
            }
            catch (System.Exception ioe)
            {
                if (ef != null)
                {
                    ef.setInstructionLabel("No Internet", ioe.Message.ToString(), Color.Green);
                    ef.Refresh();
                    success = false;
                }
            }
            finally
            {
            }
            return success;
        }

        public static bool SignInSavedData(EntryForm ef, string date, string id)
        {
            MSIWebTraxCheckInSoapClient clientChkIn = new MSIWebTraxCheckInSoapClient("MSIWebTraxCheckInSoap");
            MSIWebTraxCheckIn.UserCredentials uc = new MSIWebTraxCheckIn.UserCredentials();
            //clientChkIn.Endpoint.Binding.CloseTimeout = new TimeSpan(0, 1, 0);
            //clientChkIn.Endpoint.Binding.OpenTimeout = new TimeSpan(0, 1, 0);
            //clientChkIn.Endpoint.Binding.ReceiveTimeout = new TimeSpan(0, 1, 0);
            //clientChkIn.Endpoint.Binding.SendTimeout = new TimeSpan(0, 1, 0);
            bool success = true;
            int deptOverride = 0;
            deptOverride = ef.EnvInfo.DepartmentID;
            for (int i = 0; i < ef.EnvInfo.Password.Count; i++)
            {
                uc.PWD = ef.EnvInfo.Password[i];
                uc.UserName = ef.EnvInfo.UserId[i];

                try
                {
                    MSIWebTraxCheckIn.RecordSwipeReturn punchReturn;
                    ef.EnvInfo.PunchInProgress++;
                    punchReturn = clientChkIn.RecordSwipeBiometric(uc, id + "|*|" +
                         date + "|*|" + ef.BiometricResult);
                    //Console.WriteLine(punchReturn.PunchSuccess + ", " + punchReturn.PunchType);
                }
                /* success simply means it was able to connect  */
                /*  not whether or not the punch was valid      */
                catch (System.Exception ioe)
                {
                    success = false;
                    i = ef.EnvInfo.Password.Count;
                }
                finally
                {
                    ef.EnvInfo.PunchInProgress--;
                    if (ef.EnvInfo.PunchInProgress < 0)
                        ef.EnvInfo.PunchInProgress = 0;
                }
            }
            return success;
        }

        public static void SignIn(object efIn)
        {
            EntryForm ef = (EntryForm)efIn;
            returnValue = true;
            if (ef.EnvInfo.MultipleClients)
            {
                SignInMultipleClients(ef);
                return;
            }

            int deptOverride = 0;
            for (int i = 0; i < ef.EnvInfo.DepartmentButtons.Count; i++)
            {
                if (ef.EnvInfo.DepartmentButtons[i].Checked)
                {
                    deptOverride = ef.EnvInfo.DepartmentIDs[i];
                }
            }
            deptOverride = ef.EnvInfo.DepartmentID;
            MSIWebTraxCheckInSoapClient clientChkIn = new MSIWebTraxCheckInSoapClient("MSIWebTraxCheckInSoap");
            MSIWebTraxCheckIn.UserCredentials uc = new MSIWebTraxCheckIn.UserCredentials();
            //clientChkIn.
            uc.PWD = ef.EnvInfo.Password[0];
            uc.UserName = ef.EnvInfo.UserId[0];
            
            try
            {
                MSIWebTraxCheckIn.RecordSwipeReturn punchReturn;

                ef.EnvInfo.PunchInProgress++;
                punchReturn = clientChkIn.RecordSwipeBiometric(uc, ef.EmpInf.IdNum + "|*|" +
                         ef.EmpInf.PunchDt.ToString() + "|*|" + ef.BiometricResult);

                string name = "";
                if( punchReturn.FirstName.Length > 0 )
                    name = punchReturn.FirstName;
                ef.setDefaultDepartment(0);  //reset to default department if necessary...
                switch (punchReturn.PunchType.ToLower())
                {
                    case "nointernet":
                        CommunicationReturnInfo.infoEng = "Punch Saved, Thank you!";
                        CommunicationReturnInfo.infoSpan = "Datos Guardados, Gracias!";
                        CommunicationReturnInfo.col = Color.Green;
                        CommunicationReturnInfo.swipeResult = -1;
                        break;
                    case "checkin":
                        CommunicationReturnInfo.infoEng = name + "\nEntrance Confirmed";
                        CommunicationReturnInfo.infoSpan = name + "\nEntrada Confirmado";
                        CommunicationReturnInfo.col = Color.Green;
                        CommunicationReturnInfo.swipeResult = 0;
                        break;
                    case "checkout":
                        CommunicationReturnInfo.infoEng = "Goodbye " + punchReturn.FirstName;
                        CommunicationReturnInfo.infoSpan = "Adios " + punchReturn.FirstName;
                        CommunicationReturnInfo.col = Color.Green;
                        CommunicationReturnInfo.swipeResult = 0;
                        break;
                    default:
                        if (punchReturn.PunchException == 2)
                        {
                            //not authorized
                            CommunicationReturnInfo.infoEng = name + " Not Authorized";
                            CommunicationReturnInfo.infoSpan = name + " No Authorizado";
                            CommunicationReturnInfo.col = Color.Red;
                            CommunicationReturnInfo.swipeResult = punchReturn.PunchException;
                        }
                        else if (punchReturn.PunchException == 1)
                        {
                            //shift not started!!
                            CommunicationReturnInfo.infoEng = name + " Shift not yet started";
                            CommunicationReturnInfo.infoSpan = name + " Trabajo no ha comenzado";
                            CommunicationReturnInfo.col = Color.Red;
                            CommunicationReturnInfo.swipeResult = punchReturn.PunchException;
                        }
                        else if (punchReturn.PunchException == 3)
                        {
                            //shift is over!!
                            CommunicationReturnInfo.infoEng = name  + " Shift has finished";
                            CommunicationReturnInfo.infoSpan = name + " Trabajo está terminado";
                            CommunicationReturnInfo.col = Color.Red;
                            CommunicationReturnInfo.swipeResult = punchReturn.PunchException;
                        }
                        else
                        {
                            CommunicationReturnInfo.infoEng = name + " Not Authorized!";
                            CommunicationReturnInfo.infoSpan = "!" + name +" No Authorizado!";
                            CommunicationReturnInfo.col = Color.Red;
                            CommunicationReturnInfo.swipeResult = punchReturn.PunchException;
                            //error  print punch exception
                        }
                        break;
                }
            }
            catch (System.Exception ioe)
            {
                //MessageBox.Show(ioe.ToString());
                returnValue = false;
                CommunicationReturnInfo.infoEng = "Punch Recorded!";
                CommunicationReturnInfo.infoSpan = "Gracias!";
                CommunicationReturnInfo.col = Color.Green;
                CommunicationReturnInfo.swipeResult = -99;
                CommunicationReturnInfo.exception = ioe;
            }
            finally
            {
                CommunicationReturnInfo.hoursWorked = 0;
                ef.EnvInfo.PunchInProgress--;
                if (ef.EnvInfo.PunchInProgress < 0)
                    ef.EnvInfo.PunchInProgress = 0;
                signInComplete();
            }
        }

        /* sign in, if 'no admittance', try next client in list */
        public static void SignInMultipleClients(object efIn)
        {
            EntryForm ef = (EntryForm)efIn;
            MSIWebTraxCheckInSoapClient clientChkIn = new MSIWebTraxCheckInSoapClient("MSIWebTraxCheckInSoap");
            MSIWebTraxCheckIn.UserCredentials uc = new MSIWebTraxCheckIn.UserCredentials();
            bool validPunch = false;
            bool returnValue = true;

            for (int i = 0; i < ef.EnvInfo.Password.Count && !validPunch; i++)
            {
                uc.PWD = ef.EnvInfo.Password[i];
                uc.UserName = ef.EnvInfo.UserId[i];
                try
                {
                    //ef.EmpInf.PunchDt = new DateTime(2016, 8, 25, 20, 21, 10);
                    ef.EnvInfo.PunchInProgress++;
                    MSIWebTraxCheckIn.RecordSwipeReturn punchReturn = clientChkIn.RecordSwipeBiometric(uc, ef.EmpInf.IdNum + "|*|" +
                        ef.EmpInf.PunchDt.ToString() + "|*|" + ef.BiometricResult);

                    string name = "";
                    if (punchReturn.FirstName.Length > 0)
                        name = punchReturn.FirstName;

                    switch (punchReturn.PunchType.ToLower())
                    {
                        case "nointernet":
                            CommunicationReturnInfo.infoEng = "Punch Saved, Thank you!";
                            CommunicationReturnInfo.infoSpan = "Datos Guardados, Gracias!";
                            CommunicationReturnInfo.col = Color.Green;
                            CommunicationReturnInfo.swipeResult = -1;
                            i = ef.EnvInfo.Password.Count;
                            break;
                        case "checkin":
                            CommunicationReturnInfo.infoEng = name + " Entrance Confirmed";
                            CommunicationReturnInfo.infoSpan = name + " Entrada Confirmado";
                            CommunicationReturnInfo.col = Color.Green;
                            CommunicationReturnInfo.swipeResult = 0;
                            i = ef.EnvInfo.Password.Count;
                            break;
                        case "checkout":
                            CommunicationReturnInfo.infoEng = "Goodbye " + name + "!";
                            CommunicationReturnInfo.infoSpan = "Adios " + name + "!";
                            CommunicationReturnInfo.col = Color.Green;
                            CommunicationReturnInfo.swipeResult = 0;
                            i = ef.EnvInfo.Password.Count;
                            break;
                        default:
                            if (i < ef.EnvInfo.Password.Count - 1)
                                break;
                            if (punchReturn.PunchException == 2)
                            {
                                //not authorized
                                CommunicationReturnInfo.infoEng = "Not Authorized";
                                CommunicationReturnInfo.infoSpan = "No Authorizado";
                                CommunicationReturnInfo.col = Color.Red;
                                CommunicationReturnInfo.swipeResult = punchReturn.PunchException;
                            }
                            else if (punchReturn.PunchException == 1)
                            {
                                //shift not started!!
                                CommunicationReturnInfo.infoEng = "Shift not yet started";
                                CommunicationReturnInfo.infoSpan = "Trabajo no ha comenzado";
                                CommunicationReturnInfo.col = Color.Red;
                                CommunicationReturnInfo.swipeResult = punchReturn.PunchException;
                            }
                            else if (punchReturn.PunchException == 3)
                            {
                                //shift is over!!
                                CommunicationReturnInfo.infoEng = "Shift has finished";
                                CommunicationReturnInfo.infoSpan = "Trabajo está terminado";
                                CommunicationReturnInfo.col = Color.Red;
                                CommunicationReturnInfo.swipeResult = punchReturn.PunchException;
                            }
                            else
                            {
                                CommunicationReturnInfo.infoEng = "Not Authorized!";
                                CommunicationReturnInfo.infoSpan = "!No Authorizado!";
                                CommunicationReturnInfo.col = Color.Red;
                                CommunicationReturnInfo.swipeResult = punchReturn.PunchException;
                                //error  print punch exception
                            }
                            break;
                    }
                }
                catch (System.Exception ioe)
                {
                    //MessageBox.Show(ioe.ToString());
                    returnValue = false;
                    CommunicationReturnInfo.infoEng = "Punch Recorded!";
                    CommunicationReturnInfo.infoSpan = "Gracias!";
                    CommunicationReturnInfo.col = Color.Green;
                    CommunicationReturnInfo.swipeResult = -99;
                    CommunicationReturnInfo.exception = ioe;
                    i = ef.EnvInfo.Password.Count;
                }
                finally
                {
                    ef.EnvInfo.PunchInProgress--;
                    if (ef.EnvInfo.PunchInProgress < 0)
                        ef.EnvInfo.PunchInProgress = 0;
                    if (i >= (ef.EnvInfo.Password.Count - 1) || returnValue == false)
                    {
                        CommunicationReturnInfo.hoursWorked = 0;
                        signInComplete();
                    }
                }
            }
        }
        public static void Pulse(EntryForm ef)
        {
            ef.KeepAliveTimer().Interval = 10000;
            ef.KeepAliveTimer().Stop();
            string uri = "http://msiwebtrax.com/Roster/Hello?time=" + DateTime.Now.ToString("yyyy/MM/dd hh:mm:ss");
            HttpWebRequest req = WebRequest.Create(uri) as HttpWebRequest;
            //req.CachePolicy = RequestCachePolicy
            req.KeepAlive = true;
            req.Method = "GET";
            HttpWebResponse resp = null;
            try
            {
                resp = req.GetResponse() as HttpWebResponse;
            }
            catch (Exception ex)
            {
                ef.KeepAliveTimer().Interval = 60000; /* wait a minute before trying again */
            }
            finally
            {
                if (resp != null)
                    resp.Close();
                ef.KeepAliveTimer().Start();
                if (ef.EnvInfo.state == State.AWAITING_ID)
                {
                    ef.setInstructionLabel("Please scan your ID", "Por favor pase su tarjeta", Color.Black);
                }
            }
        }
    }
}