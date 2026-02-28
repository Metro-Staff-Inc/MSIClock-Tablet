using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows.Forms;
using System.ComponentModel;
using System.Drawing;
using System.Xml;
using System.Diagnostics;
using System.IO;
using System.Drawing.Imaging;
using System.Net.Mail;
using System.Threading;
//using System.Windows.Automation;
namespace FingerprintVerification
{

    delegate void Function();


    public partial class EntryForm : Form, DPFP.Capture.EventHandler
    {
        public EnvironmentInfo EnvInfo { get; set; }
        public int BiometricResult { get; set; }

        ComponentResourceManager resources = new ComponentResourceManager(typeof(EntryForm));
        private List<EmployeeInfo> employees = new List<EmployeeInfo>();
        private List<DPFP.Template> Template;
        DPFP.Capture.Capture Capturer;
        private DPFP.Verification.Verification Verificator;
        static private DPFP.Verification.Verification StaticVerificator;
        DPFP.Verification.Verification.Result result;
        public static Boolean skipVerification = false;


        public static string clientID;

        private String startUpInfo = "";
        private Boolean scheduledReboot = false;
        private static Int32 MAX_FINGERPRINT_ATTEMPTS = 10;
        private Int32 fingerprintAttemptCount = 0;
        PictureBox empty = new PictureBox();
        PictureBox accept = new PictureBox();
        PictureBox reject = new PictureBox();
        EntryForm entryForm;

        
        Font blackFont = new System.Drawing.Font("Microsoft Sans Serif", 16F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
        Font blackFontSmall = new System.Drawing.Font("Microsoft Sans Serif", 16F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
        Font blueFont = new System.Drawing.Font("Microsoft Sans Serif", 24F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
        Font redFont = new System.Drawing.Font("Microsoft Sans Serif", 24F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
        
        public System.Windows.Forms.Timer KeepAliveTimer()
        {
            return tmrKeepAlive;
        }
        private EmployeeInfo _empInf;
        public EmployeeInfo EmpInf
        {
            get { return _empInf; }
            set { _empInf = value; }
        }

        public void signIn(EntryForm ef, bool asynch)
        {
            if (asynch == false)
            {
                Communication.SignIn(ef); 
            }
            else if (EnvInfo.ReportHours)
            {
                //Communication.SignInWithSummary(ef);
                Thread newThread = new Thread(Communication.SignInWithSummary);
                newThread.Start(ef);
            }
            else
            {
                Thread newThread = new Thread(Communication.SignIn);
                newThread.Start(ef);
            }
        }

        public void Communication_signInComplete()
        {
            try
            {
                if (EnvInfo.state != State.FINGERPRINT_OVERRIDE)
                {
                    setInstructionLabel(CommunicationReturnInfo.infoEng, CommunicationReturnInfo.infoSpan,
                        CommunicationReturnInfo.col);

                    this.Invoke((MethodInvoker)delegate
                    {
                        //Refresh();
                        tmrEnter.Interval = 4000;
                        tmrEnter.Start();
                    });
                }

                if (CommunicationReturnInfo.swipeResult == -99 && EnvInfo.CameraName != null)
                {
                    /* save image with different name so it can be be uploaded later... */
                    if (!File.Exists(EnvInfo.ImageDir + "_" + EnvInfo.CameraName + "__" + EmpInf.PicName))
                    {
                        try
                        {
                            File.Copy(EnvInfo.ImageDir + EmpInf.PicName, EnvInfo.ImageDir + "_" + EnvInfo.CameraName + "__" + EmpInf.PicName);
                        }
                        catch (FileNotFoundException fnfe)
                        {
                            fnfe = null;
                        }
                        catch (NullReferenceException nre)
                        {
                            nre = null;
                        }
                        catch (IOException ioe)
                        {
                            ioe = null;
                        }
                    }
                }
                else if (CommunicationReturnInfo.swipeResult > 0 && EnvInfo.NotAuthorizedEmail != null)
                {
                    SendNotAuthorizedEmail(CommunicationReturnInfo.swipeResult);
                }
                if (EmpInf.Email != null)
                {
                    SendSwipeConfirmationEmail();
                }
                if( CommunicationReturnInfo.hoursWorked >= EnvInfo.OTHoursLimit && CommunicationReturnInfo.checkIn == true )
                    SendOTWarningEmail();
            }
            catch (NullReferenceException nre)
            {
                nre = null;
            }
        }

        public void SetEnvironmentInfo()
        {            
            EnvInfo = new EnvironmentInfo();
            String deptName = Environment.GetEnvironmentVariable("FPT_DepartmentName");
            String deptID = Environment.GetEnvironmentVariable("FPT_DepartmentID");
            EnvInfo.DepartmentName = deptName;
            EnvInfo.DepartmentID = Convert.ToInt32(deptID);

            lblDepartmentName.Text = EnvInfo.DepartmentName;


            String depts = Environment.GetEnvironmentVariable("FPT_DepartmentOverride");
            EnvInfo.DepartmentIDs = new List<int>();
            EnvInfo.DepartmentNames = new List<String>();
            EnvInfo.DepartmentButtons = new List<RadioButton>();
            if (depts != null)
            {
                String[] d = depts.Split(',');
                EnvInfo.DepartmentButtons.Add(rbDefaultDept);
                EnvInfo.DepartmentIDs.Add(0);
                EnvInfo.DepartmentNames.Add("Default Department");
                EnvInfo.DepartmentButtons.Add(rbDept1);
                EnvInfo.DepartmentButtons.Add(rbDept2);
                EnvInfo.DepartmentButtons.Add(rbDept3);
                EnvInfo.DepartmentButtons.Add(rbDept4);
                for( int i=0; i<d.Length; i+=2 ) 
                {
                    if (d[i].Trim().Length == 0) continue;
                    EnvInfo.DepartmentNames.Add(d[i+1]);
                    EnvInfo.DepartmentIDs.Add(Convert.ToInt32(d[i]));
                }
                for( int i=0; i<EnvInfo.DepartmentButtons.Count; i++ )
                {
                    if( i<EnvInfo.DepartmentNames.Count )
                    {
                        EnvInfo.DepartmentButtons[i].Text = EnvInfo.DepartmentNames[i].Trim();
                    }
                    else
                    {
                        EnvInfo.DepartmentButtons[i].Visible = false;
                    }
                }
            }

            EnvInfo.PunchInProgress = 0;    /* no punches yet */
            EnvInfo.ClientName = Environment.GetEnvironmentVariable("FPT_ClientName");
            /***DELETE!***/
            //EnvInfo.ClientName = "WeberHuntley";

            startUpInfo += "<br/>Client: " + EnvInfo.ClientName + "<br/>";

            
            String nameSize = "24";
            try
            {
                nameSize = Environment.GetEnvironmentVariable("FPT_NameSize");
            }
            catch (Exception e) { }
            EnvInfo.NameSize = Convert.ToInt32(nameSize);

            string dir = Environment.GetEnvironmentVariable("FPT_Dir");
            EnvInfo.Dir = dir;
            startUpInfo += "Client directory: " + EnvInfo.Dir + "<br/>";

            EnvInfo.SendBootupEmail = true;
            if (Environment.GetEnvironmentVariable("FPT_SendBootupEmail") != null)
                EnvInfo.SendBootupEmail = Convert.ToBoolean(Environment.GetEnvironmentVariable("FPT_SendBootupEmail"));

            if (Environment.GetEnvironmentVariable("FPT_CameraName") != null)
                EnvInfo.CameraName = Environment.GetEnvironmentVariable("FPT_CameraName");
            else
                EnvInfo.CameraName = "NoCameraName";
            startUpInfo += "Camera Name: " + EnvInfo.CameraName + "<br/>";            

            EnvInfo.RebootTime = new List<DateTime>();
            DateTime curDate = DateTime.Now;
            if (Environment.GetEnvironmentVariable("FPT_RebootTime") != null)
            {
                String dt = Environment.GetEnvironmentVariable("FPT_RebootTime");
                EnvInfo.RebootTime.Add(Convert.ToDateTime(dt));
                TimeSpan diff = (curDate - EnvInfo.RebootTime[0]).Duration();
                startUpInfo += "Scheduled Reboot Time #1: " + EnvInfo.RebootTime[0].ToString("hh:mm:ss") + "<br/>";
                if( (diff.Hours == 0 && diff.Minutes <= 3) )
                    scheduledReboot = true;
            }
            if (Environment.GetEnvironmentVariable("FPT_RebootTime2") != null)
            {
                String dt = Environment.GetEnvironmentVariable("FPT_RebootTime2");
                EnvInfo.RebootTime.Add(Convert.ToDateTime(dt));
                TimeSpan diff = (curDate - EnvInfo.RebootTime[1]).Duration();
                startUpInfo += "Scheduled Reboot Time #2: " + EnvInfo.RebootTime[1].ToString("hh:mm:ss") + "<br/>";
                if ((diff.Hours == 0 && diff.Minutes <= 3))
                    scheduledReboot = true;
            }
            if (scheduledReboot == false)
                startUpInfo += "<hr/><h1 style='color:Red'>This is an unscheduled reboot!</h1>";


            /* get build date */
            EnvInfo.BuildDate = Version.RetrieveLinkerTimestamp().ToString("yyyyMMdd");

            startUpInfo += "Build Date: " + EnvInfo.BuildDate + "<br/>";
            /* get dropbox location */
            if (Directory.Exists(@"C:\dropbox"))
            {
                EnvInfo.Homedrive = @"c:";
            }
            else if (Directory.Exists(@"C:\inetpub\wwwroot\dropbox\"))
            {
                EnvInfo.Homedrive = @"c:\inetpub\wwwroot";
            }
            else
            {
                EnvInfo.Homedrive = Environment.GetEnvironmentVariable("HOMEDRIVE");
                MessageBox.Show("Dropbox should be located in the root of c:!");
            }
            startUpInfo += "DropBox Location = " + EnvInfo.Homedrive + "<br/>";

            EnvInfo.Fingerprints = Convert.ToBoolean(Environment.GetEnvironmentVariable("FPT_Fingerprint"));
            //EnvInfo.Fingerprints = false;
            EnvInfo.Camera = Convert.ToBoolean(Environment.GetEnvironmentVariable("FPT_Camera"));
            EnvInfo.Camera = true;
            EnvInfo.Pulse = Convert.ToBoolean(Environment.GetEnvironmentVariable("FPT_Pulse"));

            startUpInfo += "Take Fingerprints: " + EnvInfo.Fingerprints + "<br/>";
            startUpInfo += "Use Camera: " + EnvInfo.Camera + "<br/>";
            startUpInfo += "Pulse To Keep Connection Open: " + EnvInfo.Pulse + "<br/>";

            EnvInfo.UserId = new List<string>();
            EnvInfo.Password = new List<string>();

            if (Environment.GetEnvironmentVariable("FPT_Client") != null)
            {
                EnvInfo.UserId.Add(Environment.GetEnvironmentVariable("FPT_Client"));
                //EnvInfo.UserId.Add("WeberHuntley");
                startUpInfo += "Client 1: " + EnvInfo.UserId[0] + "<br/>";
            }
            if (Environment.GetEnvironmentVariable("FPT_Client2") != null)
            {
                EnvInfo.UserId.Add(Environment.GetEnvironmentVariable("FPT_Client2"));
                startUpInfo += "Client 2: " + EnvInfo.UserId[1] + "<br/>";
            }
            if (Environment.GetEnvironmentVariable("FPT_Client3") != null)
            {
                EnvInfo.UserId.Add(Environment.GetEnvironmentVariable("FPT_Client3"));
                startUpInfo += "Client 3: " + EnvInfo.UserId[2] + "<br/>";
            }
            if (Environment.GetEnvironmentVariable("FPT_Client4") != null)
            {
                EnvInfo.UserId.Add(Environment.GetEnvironmentVariable("FPT_Client4"));
                startUpInfo += "Client 4: " + EnvInfo.UserId[3] + "<br/>";
            }

            if (Environment.GetEnvironmentVariable("FPT_Pwd") != null)
            {
                EnvInfo.Password.Add(Environment.GetEnvironmentVariable("FPT_Pwd"));
                //EnvInfo.Password.Add("Winter1972");
            }
            if (Environment.GetEnvironmentVariable("FPT_Pwd2") != null)
                EnvInfo.Password.Add(Environment.GetEnvironmentVariable("FPT_Pwd2"));
            if (Environment.GetEnvironmentVariable("FPT_Pwd3") != null)
                EnvInfo.Password.Add(Environment.GetEnvironmentVariable("FPT_Pwd3"));
            if (Environment.GetEnvironmentVariable("FPT_Pwd4") != null)
                EnvInfo.Password.Add(Environment.GetEnvironmentVariable("FPT_Pwd4"));

            //EnvInfo.ReportHours = true;
            if (Environment.GetEnvironmentVariable("FPT_ReportHours") != null)
            {
                String dt = Environment.GetEnvironmentVariable("FPT_ReportHours");
                EnvInfo.ReportHours = Convert.ToBoolean(dt);
            }
            //EnvInfo.ReportHours = true;

            if( EnvInfo.ReportHours )
            {
                startUpInfo += "This clock is set to display accumulated hours.<br/>";
            }
            else
            {
                startUpInfo += "This clock does not display accumulated hours for the week.<br/>";
            }

            if (Environment.GetEnvironmentVariable("FPT_NoDropbox") != null)
            {
                EnvInfo.NoDropbox = Convert.ToBoolean(Environment.GetEnvironmentVariable("FPT_NoDropbox"));
                startUpInfo += "Using Dropbox: " + !EnvInfo.NoDropbox + "<br/>";
            }
            EnvInfo.MultipleClients = EnvInfo.UserId.Count > 1;

            EnvInfo.Timeout = 20;                                                    
            EnvInfo.Timeout = Convert.ToInt32(Environment.GetEnvironmentVariable("FPT_Timeout"));
            startUpInfo += "Timeout length: " + EnvInfo.Timeout + " seconds." + "<br/>";

            string str = Environment.GetEnvironmentVariable("FPT_NotAuthorizedEmail");

            EnvInfo.NotAuthorizedEmail = new List<string>();
            if (str != null)
            {
                EnvInfo.NotAuthorizedEmail = str.Split(',').ToList<string>();
                startUpInfo += "Not Authorized Email Notices To: " + str + "<br/>";
            }
            else
            {
                startUpInfo += "Not Authorized Notices will not be sent out!<br/>";
            }

            EnvInfo.BootupEmail = new List<string>();
            str = Environment.GetEnvironmentVariable("FPT_BootupEmail");
            if (str == null)
                str = "jmurfey@msistaff.com";
            if (str != null)
            {
                EnvInfo.BootupEmail = str.Split(',').ToList<string>();
                startUpInfo += "Bootup Email Notices Sent To: " + str + "<br/>";
            }

            str = Environment.GetEnvironmentVariable("FPT_Email");

            EnvInfo.FingerprintFailedEmail = new List<string>();
            if (str != null)
            {
                EnvInfo.FingerprintFailedEmail = str.Split(',').ToList<string>();
                startUpInfo += "Biometric Failure Email Notices To: " + str + "<br/>";
            }
            else
            {
                startUpInfo += "NO Biometric Failure Email Notices will be sent!<br/>";
            }
            str = Environment.GetEnvironmentVariable("FPT_OTWarningEmail");
            EnvInfo.OTWarningEmail = new List<string>();
            if (str != null)
            {
                EnvInfo.OTWarningEmail = str.Split(',').ToList<string>();

                startUpInfo += "Overtime Warning Email Notices To: " + str + "<br/>";

                string s = Environment.GetEnvironmentVariable("FPT_OTHoursLimit");

                if (s != null)
                    EnvInfo.OTHoursLimit = Convert.ToInt32(s);
                else
                    EnvInfo.OTHoursLimit = 9999;

                startUpInfo += "Overtime hours limit: " + EnvInfo.OTHoursLimit + "<br/>";
            }
            else
            {
                startUpInfo += "No Overtime Warning Emails will be sent!<br/>";
            }

            EnvInfo.ImageDir = EnvInfo.Homedrive + "\\Dropbox\\images\\" + 
                        dir +"\\";
            EnvInfo.ServerImages = "http://meotrax.azurewebsites.net/dropbox/images/" + dir + "/";
            EnvInfo.ShiftData = EnvInfo.Homedrive + "\\Dropbox\\shiftdata\\";

            EnvInfo.state = State.AWAITING_ID;
            EnvInfo.PlaceHolderImage = pictBoxPlaceholder.Image;//Image.FromFile("../../Images/chkbox.png");

            EnvInfo.LEDDisplay = true;
            str = Environment.GetEnvironmentVariable("FPT_LEDDisplay");
            if (str != null && str.ToUpper().Equals("TRUE"))
            {
                EnvInfo.LEDDisplay = true;
                //init command window
            }
            if (EnvInfo.LEDDisplay == true)
            {
                OutputToLEDDisplay(" ", true);
                OutputToLEDDisplay("Starting up!", true);
            }
        }

        public void OutputToLEDDisplay(String outp, bool newLine)
        {
            System.Diagnostics.Process process = new System.Diagnostics.Process();
            System.Diagnostics.ProcessStartInfo startInfo = new System.Diagnostics.ProcessStartInfo();
            startInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
            startInfo.FileName = "cmd.exe";
            if (!newLine)
                startInfo.Arguments = "/C <nul set /p =" + outp + "> //.////LCLD9//";//"; ///C copy /b Image1.jpg + Archive.rar Image2.jpg
            else
                startInfo.Arguments = "/C echo " + outp + "> //.////LCLD9//";
            process.StartInfo = startInfo;
            process.Start();
        }

        public EntryForm()
        {
            /* layout of form */
            InitializeComponent();

            /* information specific to punch clock */
            SetEnvironmentInfo();

            /* set build date */

            /* add method to communication finished callback */
            Communication.signInComplete += new MyEventHandler(Communication_signInComplete);

            EmpInf = new EmployeeInfo();
            if (EnvInfo.Fingerprints)
            {
                Capturer = new DPFP.Capture.Capture();            
                /* fire up the fingerprint scanner */
                InitCapturer();
                ///* turn on the verifier */
                StaticVerificator = new DPFP.Verification.Verification();		// Create a default fingerprint template verificator
            }

            loadVerificationImages();
            if( EnvInfo.SendBootupEmail )
            {
                SendBootUpEmail();
            }
            tmrClock.Start();
            entryForm = this;
            txtIdNumber.Focus();

        }

        public void deleteExpiredImages( String Location )
        {
            int curDayOfYear = DateTime.Now.DayOfYear;

            System.IO.DirectoryInfo dir = new System.IO.DirectoryInfo(Location);
            /* create employee list based on fingerprint templates in dir */
            /* get the name and shift info from the xml file, if available */

            /* find matching id num in employee list */
            foreach (System.IO.FileInfo f in dir.GetFiles("*.jpg"))
            {
                int st = f.Name.IndexOf("__") + 2;
                int end = f.Name.Length - st - 4;
                String dtStr = f.Name.Substring(st, end);
                DateTime dt = new DateTime(Convert.ToInt32(dtStr.Substring(0, 4)), 
                    Convert.ToInt32(dtStr.Substring(4, 2)), 
                        Convert.ToInt32(dtStr.Substring(6, 2)));
                TimeSpan ts = DateTime.Now - dt;                
                if (ts.TotalDays > 60)
                {
                    f.Delete();
                }
            }
        }

        public void reboot()
        {
            tmrKeepAlive.Stop();
            lblInstructions2.Text = "Rebooting - one moment...";
            lblInstructions.Text = "Re-booting - un momento...";
            Refresh();

            ShutDown.DoExitWin(ShutDown.EWX_REBOOT);
        }

        public void resetCam()
        {
            if (EnvInfo.Camera == false)
                return;
            stopCam();
            lblInstructions2.Text = "Resetting Camera";
            lblInstructions.Text = "Nuevo Camera";
            Refresh();

            this.Controls.Remove(this.pictVideoStream);
            this.pictVideoStream = null;

            //MessageBox.Show("pictVideo deleted!");
            //WebCamCapture.Stop();

            this.pictVideoStream = new System.Windows.Forms.PictureBox();
            ((System.ComponentModel.ISupportInitialize)(this.pictVideoStream)).BeginInit();

            this.pictVideoStream.Location = new System.Drawing.Point(772, 35);
            this.pictVideoStream.Name = "pictVideoStream";
            this.pictVideoStream.Size = new System.Drawing.Size(320, 240);
            this.pictVideoStream.TabIndex = 2;
            this.pictVideoStream.TabStop = false;
            this.Controls.Add(this.pictVideoStream);

            ((System.ComponentModel.ISupportInitialize)(this.pictVideoStream)).EndInit();
            
            this.WebCamCapture = new WebCam_Capture.WebCamCapture();
            this.WebCamCapture.CaptureHeight = this.pictVideoStream.Height;
            this.WebCamCapture.CaptureWidth = this.pictVideoStream.Width;
            this.WebCamCapture.CaptureHeight = 240;
            this.WebCamCapture.CaptureWidth = 320;
            this.WebCamCapture.FrameNumber = ((ulong)(0ul));
            this.WebCamCapture.Location = new System.Drawing.Point(0, 0);
            this.WebCamCapture.Name = "WebCamCapture";
            this.WebCamCapture.Size = new System.Drawing.Size(342, 252);
            this.WebCamCapture.TabIndex = 0;
            this.WebCamCapture.TimeToCapture_milliseconds = 100;
            this.WebCamCapture.ImageCaptured += new WebCam_Capture.WebCamCapture.WebCamEventHandler(this.webCamCapture1_ImageCaptured);

            this.pictBoxEmailImage = new System.Windows.Forms.PictureBox();

            startCam();
            this.txtIdNumber.Text = "";

            EnvInfo.state = State.AWAITING_ID;
            setState();
        }
        public void setDefaultDepartment(int x)
        {
            this.Invoke((MethodInvoker)delegate
            {
                if (EnvInfo.DepartmentButtons.Count > 0 && (x >= EnvInfo.DepartmentIDs.Count || x == 0))
                {
                    EnvInfo.DepartmentButtons[0].Checked = true;
                }
                else
                {
                    for (int i = 1; i < EnvInfo.DepartmentButtons.Count; i++)
                    {
                        EnvInfo.DepartmentButtons[i].Checked = false;
                        if (i == x)
                            EnvInfo.DepartmentButtons[i].Checked = true;
                    }
                }
            });
        }
        public void setInstructionLabel( String s, String s2, Color c )
        {
            this.Invoke((MethodInvoker)delegate
            {
                lblInstructions2.ForeColor = c;
                lblInstructions.ForeColor = c;
                lblInstructions2.Text = s;
                lblInstructions.Text = s2;
                Refresh();
            });
        }

        private void loadVerificationImages()
        {
            accept.Image = (Bitmap)resources.GetObject("pictBoxHidden.Image");
            accept.BackColor = Color.Transparent;
            empty.Image = (Bitmap)resources.GetObject("picAttempt1.BackgroundImage");
            empty.BackColor = Color.Transparent;
            reject.Image = (Bitmap)resources.GetObject("pictBoxHidden.BackgroundImage");
            reject.BackColor = Color.Transparent;
        }

        private void EntryForm_Load(object sender, System.EventArgs e)
        {
            this.Text = "MEO Entry Tracker - " + EnvInfo.BuildDate;
            // set the image capture size
            //var asForm = System.Windows.Automation.AutomationElement.FromHandle(this.Handle);
            //Process.Start(@"C:\Windows\System32\osk.exe");
            this.WebCamCapture.CaptureHeight = this.pictVideoStream.Height;
            this.WebCamCapture.CaptureWidth = this.pictVideoStream.Width;
            startCam();
        }

        private void EntryForm_Closing(object sender, System.ComponentModel.CancelEventArgs e)
        {
            // stop the video capture
            if( EnvInfo.Camera == true )
                this.WebCamCapture.Stop();
        }

        private void startCam()
        {
            if (EnvInfo.Camera != true)
                return;
            // change the capture time frame
            this.WebCamCapture.TimeToCapture_milliseconds = 20;//(int)this..Value;
            // start the video capture. let the control handle the
            // frame numbers.
            this.WebCamCapture.Start(0);
            //MakeReport("Camera started");
        }

        private void stopCam()
        {
            //MakeReport("Stopping camera");
            // stop the video capture
            if( EnvInfo.Camera == true )
                this.WebCamCapture.Stop();
        }

        protected virtual Boolean InitCapturer()
        {
            try
            {
                Capturer = new DPFP.Capture.Capture();				// Create a capture operation.

                if (null != Capturer)
                    Capturer.EventHandler = this;					// Subscribe for capturing events.
                else
                {
                    //MessageBox.Show("Can't initiate capture operation!", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return false;
                }
            }
            catch
            {
                //MessageBox.Show("Can't initiate capture operation!", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return false;
            }
            //MessageBox.Show("Init Capturer!");
            return true;
        }
        
        private void ClearPicture()
        {
            if (EnvInfo.Camera == false)
                return;
            this.Invoke(new Function(delegate()
            {
                pictFingerprint1.BackgroundImage = (Bitmap)resources.GetObject("pictBoxHidden2.BackgroundImage");
                //pictFingerprint.Visible = false;
            }));
        }

        private void DrawPicture(Bitmap bitmap)
        {
            this.Invoke(new Function(delegate()
            {
                Bitmap bmp = new Bitmap(bitmap, pictFingerprint1.Size);	// fit the image into the picture box
                //bmp.MakeTransparent();
                pictFingerprint1.BackgroundImage = bmp; 
                //pictFingerprint1.Image.
                pictFingerprint1.Visible = true;
            }));
        }

        protected Bitmap ConvertSampleToBitmap(DPFP.Sample Sample)
        {
            DPFP.Capture.SampleConversion Convertor = new DPFP.Capture.SampleConversion();	// Create a sample convertor.
            Bitmap bitmap = null;												            // TODO: the size doesn't matter
            Convertor.ConvertToPicture(Sample, ref bitmap);									// TODO: return bitmap as a result
            return bitmap;
        }

        private void loadEmployeeInfo(String id)
        {
            FileInfo f = new FileInfo(EnvInfo.ShiftData + id + ".xml");
            if (f.Exists)
            {
                XmlTextReader reader = new XmlTextReader(f.Directory + "\\" + f.Name);
                String element = null;
                EmpInf = new EmployeeInfo();
                EmpInf.Template = new List<DPFP.Template>();
                Random rnd = new Random();
                while (reader.Read())
                {
                    switch (reader.NodeType)
                    {
                        case XmlNodeType.Element: // The node is an element.
                            Debug.Write("<" + reader.Name);
                            Debug.WriteLine(">");
                            element = reader.Name;
                            break;
                        case XmlNodeType.Text: //Display the text in each element.
                            Debug.WriteLine(reader.Value);
                            if (element.Equals("ID"))
                                EmpInf.IdNum = reader.Value;
                            else if (element.Equals("LastName"))
                                EmpInf.LastName = reader.Value;
                            else if (element.Equals("FirstName"))
                                EmpInf.FirstName = reader.Value;
                            else if (element.Equals("Shift"))
                                EmpInf.Shift = reader.Value;
                            else if (element.Equals("Department"))
                                EmpInf.Dept = reader.Value;
                            else if (element.Equals("FAR"))
                                EmpInf.FptLevel = Convert.ToInt32(reader.Value);
                            else if (element.Equals("Email"))
                            {
                                string str = reader.Value;
                                EmpInf.Email = str.Split(',').ToList<String>();
                            }
                            break;
                        case XmlNodeType.EndElement: //Display the end of the element.
                            Debug.Write("</" + reader.Name);
                            Debug.WriteLine(">");
                            break;
                    }
                }
                reader.Close();
                string[] fingerList = { "RT", "R1", "R2", "R3", "R4", "LT", "L1", "L2", "L3", "L4" };
                foreach (string finger in fingerList)
                {
                    f = new FileInfo(EnvInfo.ShiftData + id + finger + ".fpt");
                    if (f.Exists)
                    {
                        DPFP.Template template = new DPFP.Template();
                        loadFingerprintTemplate(f.Directory + "\\" + f.Name, ref template);
                        EmpInf.Template.Add(template);
                    }
                }
                EmpInf.LastName += " - " + EmpInf.Template.Count;
            }
            else
            {
                EmpInf = new EmployeeInfo();
                EmpInf.Template = new List<DPFP.Template>();
                EmpInf.FirstName = "Card Swiped";
                EmpInf.IdNum = id;
            }
        }

        private void loadFingerprintTemplate(String file, ref DPFP.Template template)
        {
            using (FileStream fs = File.OpenRead(file))
            {
                template = new DPFP.Template(fs);
            }
        }

        protected DPFP.FeatureSet ExtractFeatures(DPFP.Sample Sample, DPFP.Processing.DataPurpose Purpose)
        {
            DPFP.Processing.FeatureExtraction Extractor = new DPFP.Processing.FeatureExtraction();	// Create a feature extractor
            DPFP.Capture.CaptureFeedback feedback = DPFP.Capture.CaptureFeedback.None;
            DPFP.FeatureSet features = new DPFP.FeatureSet();
            Extractor.CreateFeatureSet(Sample, Purpose, ref feedback, ref features);			// TODO: return features as a result?
            if (feedback == DPFP.Capture.CaptureFeedback.Good)
                return features;
            else
                return null;
        }

        private void OnTemplate(List<DPFP.Template> template)
        {
            this.Invoke(new Function(delegate()
            {
                Template = template;
                if (Template.Count != 0)
                {
                    //MessageBox.Show("Fingerprint template is loaded and ready for use.",
                    //    "Fingerprint load");
                    //state = State.AWAITING_FINGERPRINT;
                    //setState();
                }
                else
                {
                    /* fingerprint template is INVALID for some reason. */
                    /*  handle that case */
                    MessageBox.Show("Fingerprint template is not valid.  Repeat fingerprint enrollment.",
                            "Fingerprint load");
                }
            }));
        }

        private void attemptFlags(Boolean visible, Boolean clear)
        {
            this.Invoke(new Function(delegate()
            {
                if (clear)
                {
                    picAttempt1.BackgroundImage = empty.Image;
                    picAttempt2.BackgroundImage = empty.Image;
                    picAttempt3.BackgroundImage = empty.Image;
                }
                picAttempt1.Visible = visible;
                picAttempt1.BackColor = System.Drawing.Color.Transparent;
                picAttempt2.Visible = visible;
                picAttempt2.BackColor = System.Drawing.Color.Transparent;
                picAttempt3.Visible = visible;
                picAttempt3.BackColor = System.Drawing.Color.Transparent;
            }));
        }


        private void setState()
        {
            String body;
            switch (EnvInfo.state)
            {
                case State.AWAITING_ID:
                    if( EnvInfo.Fingerprints )
                        Capturer.StopCapture();
                    setDisplayForID();
                    break;
                case State.AWAITING_FINGERPRINT:
                    Capturer.StartCapture();
                    setDisplayForFingerprint();
                    break;
                case State.TIMEOUT_NO_FINGERPRINT:
                    Capturer.StopCapture();
                    
                    this.Invoke((MethodInvoker)delegate
                    {
                        setInstructionLabel("Please wait...", "Un momento, por favor...", Color.Blue);
                        tmrAdmitDelay.Stop();
                        EnvInfo.state = State.FINGERPRINT_FAILURE;
                        BiometricResult = 1;
                        signIn(this, true);
                    });

                    body = EmpInf.FirstName + " " + EmpInf.LastName + "'s" + " fingerprint did not register with the scanner.";
                    SendHTMLEMail("Fingerprint Verification Failed!", body, "jonathanmurfey@hotmail.com");
                    break;
                case State.FINGERPRINT_OVERRIDE:
                    Capturer.StopCapture();
                    this.Invoke((MethodInvoker)delegate
                    {
                        setInstructionLabel("Please wait...", "Un momento, por favor...", Color.Blue);
                        //Refresh();
                        tmrAdmitDelay.Stop();
                        BiometricResult = 2;
                    });
                    signIn(this, false); /* wait here until the override is signed in */
                    body = EmpInf.FirstName + " " + EmpInf.LastName + "  did not scan fingerprints.";
                    SendHTMLEMail("Fingerprint Verification Failed!", body, "jonathanmurfey@hotmail.com");
                    break;
                case State.FINGERPRINT_FAILURE:
                    Capturer.StopCapture();
                    setInstructionLabel("Please wait...", "Un momento, por favor...", Color.Blue);
                    body = EmpInf.FirstName + " " + EmpInf.LastName + "'s fingerprint ID did not match the stored template.";
                    SendHTMLEMail("Fingerprint ID failed to match", body, "jonathanmurfey@hotmail.com");
                    tmrAdmitDelay.Stop();
                    BiometricResult = 3;
                    signIn(this, true);
                    break;
                case State.NO_FINGERPRINTS_ON_FILE:
                    Capturer.StopCapture();
                    this.Invoke((MethodInvoker)delegate
                    {
                        setInstructionLabel("Fingerprints not yet taken!", "One moment...Un momento, por favor...", Color.Blue);
                        setDisplayForNoFingerprint();
                        ClearPicture();
                        tmrAdmitDelay.Stop();
                        BiometricResult = 4;
                        signIn(this, true);
                    });
                    body = EmpInf.FirstName + " " + EmpInf.LastName + " has not yet had their fingerprints scanned!";
                    SendHTMLEMail("NO Fingerprints on file", body, "jonathanmurfey@hotmail.com");
                    break;
                case State.ID_CONFIRMED:
                    if( EnvInfo.Fingerprints )
                        Capturer.StopCapture();

                        MakeReport("Identity Confirmed");
                        setInstructionLabel("Please wait...", "Un momento, por favor...", Color.Blue);

                        if (EmpInf.FirstName != null)
                        {
                            lblName.Text = EmpInf.FirstName + " ";
                        }
                        if (EmpInf.LastName != null)
                        {
                            lblName.Text += EmpInf.LastName;
                        }
                        if (lblName.Text.Length > 16)
                            this.lblName.Font = new System.Drawing.Font("Microsoft Sans Serif", 16F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
                        else
                            this.lblName.Font = new System.Drawing.Font("Microsoft Sans Serif", 16F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));

                        tmrAdmitDelay.Stop();
                        BiometricResult = 0;
                        signIn(this, true);
                        //Communication.SignInWithSummary(this);
                        //Communication.SignIn(this);
                    //});
                    break;
                case State.ID_NOT_RECOGNIZED:
                    break;
                case State.FINGERPRINT_NOT_RECOGNIZED:
                    setInstructionLabel("Fingerprint Not Recognized.", "Yo No Se El Dedo.", Color.Red);
                    tmrEnter.Interval = 1000;
                    tmrEnter.Start();
                    break;
            }
        }

        private void setDisplayForID()
        {
            this.Invoke(new Function(delegate()
            {
                MakeReport("Waiting for ID");
                lblInstructions2.Text = "Please scan your ID";
                lblInstructions.Text = "Por favor pase su tarjeta";
                lblInstructions2.ForeColor = Color.Black;
                lblInstructions.ForeColor = Color.Black;
                txtIdNumber.Visible = true;
                //btnSubmitId.Visible = true;
                lblID.Text = "";
                //txtIdNumber.Text = "";
                txtIdNumber.Focus();
                //pictPortrait.Image = null;
                pictBoxEmailImage.Image = null;
                lblName.Text = "";
            }));
            ClearPicture();
            if (EnvInfo.Fingerprints)
                attemptFlags(true, true);
            else
                attemptFlags(false, true);
        }

        private void setDisplayForNoFingerprint()
        {
            this.Invoke(new Function(delegate()
            {
                MakeReport("Fingerprints not on file.");
                txtIdNumber.Text = "";
                //txtIdNumber.Visible = false;
                //btnSubmitId.Visible = false;
                if (EmpInf.Pic != null)
                {
                    ////pictPortrait.Image = EmpInf.Pic;
                }
                if (EmpInf.FirstName != null)
                {
                    lblName.Text = EmpInf.FirstName + " ";
                }
                if (EmpInf.LastName != null)
                {
                    lblName.Text += EmpInf.LastName;
                    if( lblName.Text.Length > EnvInfo.NameSize )
                    {
                        lblName.Text = lblName.Text.Substring(0,EnvInfo.NameSize);
                    }
                }
                if (EmpInf.IdNum != null)
                {
                    lblID.Text = EmpInf.IdNum;
                }
                if (EmpInf.Dept != null)
                {
                    ////lblDepartment.Text = EmpInf.Dept;
                }
                //OnTemplate(EmpInf.Template);
            }));
            if (EnvInfo.Fingerprints)
                attemptFlags(true, false);
            else
                attemptFlags(false, true);
        }

        private void setDisplayForFingerprint()
        {
            this.Invoke(new Function(delegate()
            {
                //this.BackColor = System.Drawing.Color.SteelBlue;
                lblInstructions2.Text = "Please scan your Fingerprint.";
                lblInstructions.Text = "Explore por favor su huella digital";
                lblInstructions2.ForeColor = Color.Black;
                lblInstructions.ForeColor = Color.Black;
                txtIdNumber.Text = "";
                //txtIdNumber.Visible = false;
                //btnSubmitId.Visible = false;
                if (EmpInf.Pic != null)
                {
                    ////pictPortrait.Image = EmpInf.Pic;
                }
                if (EmpInf.FirstName != null)
                {
                    lblName.Text = EmpInf.FirstName + " ";
                }
                if (EmpInf.LastName != null)
                {
                    lblName.Text += EmpInf.LastName;
                }
                if (lblName.Text.Length > 14)
                    this.lblName.Font = new System.Drawing.Font("Microsoft Sans Serif", 14F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
                else
                    this.lblName.Font = new System.Drawing.Font("Microsoft Sans Serif", 18F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
                if (EmpInf.IdNum != null)
                {
                        lblID.Text = EmpInf.IdNum;
                }
            }));
            if (EnvInfo.Fingerprints)
                attemptFlags(true, false);
            else
                attemptFlags(false, true);
        }

        /* ID Card has been swiped */
        private void idSubmitted()
        { //00699__20140427_140856
            if (txtIdNumber.Text.Length == 0)
                return;
            if( txtIdNumber.Text.Length == 1 )
            {
                try
                {
                    int dept = Convert.ToInt32(txtIdNumber.Text);
                    setDefaultDepartment(dept);
                    txtIdNumber.Text = "";
                }
                catch(Exception e)
                {
                    txtIdNumber.Text = "";
                }
                return;
            }
            if (txtIdNumber.Text.ToLower().Equals("camera"))
            {
                resetCam();
                return;
            }

            String id = txtIdNumber.Text.ToUpper().Trim();
            //OutputToLEDDisplay(id + " ", false);

            int pos = id.Length;
            String tempId = "";
            for (int i = 0; i < pos; i++)
                if (id[i] >= '0' && id[i] <= '9')
                    tempId += id[i];
            id = tempId;

            if (id.Length == 0)
            {
                txtIdNumber.Text = "";
                return;
            }

            /* First!  Check if system is waiting for a fingerprint from a different employee... */
            if (EnvInfo.state == State.AWAITING_FINGERPRINT )
            {
                if (!id.Equals(EmpInf.IdNum))
                {
                    EnvInfo.state = State.FINGERPRINT_OVERRIDE;
                    setState();//JHM2013
                }
                else
                {
                    txtIdNumber.Text = "";
                    return;
                }
            }

            fingerprintAttemptCount = 0;
            txtIdNumber.Text = id;
            EmpInf = null;
            Boolean found = false;
            #region FirstCheckStoredIDs
            //MessageBox.Show("ID = " + id);
            foreach (EmployeeInfo ei in employees)
            {
                if (id.Equals(ei.IdNum))
                {
                    found = true;
                    EmpInf = ei;
                    if( EnvInfo.Fingerprints )
                    {
                        if (ei.Template.Count > 0)
                        {
                            EnvInfo.state = State.AWAITING_FINGERPRINT;
                            //setState();
                            tmrEnter.Stop();
                        }
                        else
                        {
                            EnvInfo.state = State.NO_FINGERPRINTS_ON_FILE;
                            //setState();
                        }
                    }
                    else
                    {
                        EnvInfo.state = State.ID_CONFIRMED;
                    }
                    break;
                }
            }
            #endregion
            if (!found)
            {
                MakeReport("Loading ID from harddrive");

                loadEmployeeInfo(id);
                if( EnvInfo.Fingerprints )
                {
                    if (EmpInf.Template.Count > 0)
                    {
                        EnvInfo.state = State.AWAITING_FINGERPRINT;
                        //setState();
                        tmrEnter.Stop();
                    }
                    else
                    {
                        EnvInfo.state = State.NO_FINGERPRINTS_ON_FILE;
                        //setState();
                    }
                }
                else
                {
                    EnvInfo.state = State.ID_CONFIRMED;
                    txtIdNumber.Text = "";
                }
            }

            EmpInf.PunchDt = DateTime.Now;
            //EmpInf.PunchDt = new DateTime(2018, 1, 28, 23, 5, 22); //***DELETE***//
            EmpInf.PicName = EmpInf.IdNum + "__" + EmpInf.PunchDt.ToString("yyyyMMdd_HHmmss") + ".jpg";
            try
            {
                Bitmap bmp = null;
                if (pictVideoStream != null && pictVideoStream.Image != null)
                {
                    bmp = new Bitmap(pictVideoStream.Image);
                }
                else
                {
                    bmp = new Bitmap(EnvInfo.PlaceHolderImage);
                }
                bmp.Save(EnvInfo.ImageDir + EmpInf.PicName, ImageFormat.Jpeg);

                if (EnvInfo.Camera && pictVideoStream != null)
                {
                    pictBoxEmailImage.Image = new Bitmap(bmp, pictBoxEmailImage.Size);
                    EmpInf.Pic = (Bitmap)pictBoxEmailImage.Image;

                    if (EnvInfo.NoDropbox)
                    {
                        MemoryStream stream = new MemoryStream();
                        bmp.Save(stream, ImageFormat.Jpeg);
                        EmpInf.PicData = stream.ToArray();

                        Communication.UploadPicture(this);
                            
                        if (EmpInf.Pic != null)
                            EmpInf.Pic.Dispose();

                        if (stream != null)
                            stream.Close(); 
                    }
                }
            }
            catch (Exception e)
            {
            }
            finally
            {
                setState();
                if (EnvInfo.Fingerprints)
                    attemptFlags(true, true);
                else
                    attemptFlags(false, true);
                ClearPicture();
                if (EmpInf.FptLevel > 0)
                    Verificator = new DPFP.Verification.Verification(EmpInf.FptLevel);
                else
                    Verificator = StaticVerificator;
                /* set the 'timeout' timer.  this is for folks who can't get the scanner to realize they are pressing their finger to it */
                tmrAdmitDelay.Interval = EnvInfo.Timeout * 1000;
                tmrAdmitDelay.Start();
            }
        }

        protected virtual Boolean Process(DPFP.Sample Sample)
        {
            // Draw fingerprint sample image.
            DrawPicture(ConvertSampleToBitmap(Sample));

            /* fingerprint has been captured */
            fingerprintAttemptCount++;

            // Process the sample and create a feature set for the enrollment purpose.
            DPFP.FeatureSet features = ExtractFeatures(Sample, DPFP.Processing.DataPurpose.Verification);

            // Check quality of the sample and start verification if it's good
            // TODO: move to a separate task
            if (features != null)
            {
                // Compare the feature set with our template
                result = new DPFP.Verification.Verification.Result();
                Boolean verifiedReturn = false;
                foreach (DPFP.Template template in EmpInf.Template)
                {
                    try
                    {
                        Verificator.Verify(features, template, ref result);
                    }
                    catch (Exception ex)
                    {
                        //MessageBox.Show("Exception! = " + ex);
                    }
                    finally
                    {
                        //UpdateStatus(result.FARAchieved);
                        if (result.Verified)
                        {
                            MakeReport("The fingerprint was VERIFIED.");
                            this.Invoke((MethodInvoker)delegate
                            {
                                if (fingerprintAttemptCount == 1)
                                {
                                    ////lblFPResult1.Text = result.FARAchieved.ToString();
                                    this.picAttempt1.BackgroundImage = accept.Image;
                                }
                                else if (fingerprintAttemptCount == 2)
                                {
                                    ////lblFPResult2.Text = result.FARAchieved.ToString();
                                    this.picAttempt2.BackgroundImage = accept.Image;
                                }
                                else
                                {
                                    ////lblFPResult3.Text = result.FARAchieved.ToString();
                                    this.picAttempt3.BackgroundImage = accept.Image;
                                }
                                EnvInfo.state = State.ID_CONFIRMED;
                                setState();
                            });
                            verifiedReturn = true;    //get out
                        }
                    }
                    if (verifiedReturn)
                        return true;
                }
                MakeReport("The fingerprint was NOT VERIFIED.");
                this.Invoke((MethodInvoker)delegate
                {
                    if( fingerprintAttemptCount % 3 == 1 )
                    {
                        this.picAttempt1.BackgroundImage = reject.Image;
                        this.picAttempt2.BackgroundImage = empty.Image;
                        this.picAttempt3.BackgroundImage = empty.Image;
                    }
                    else if( fingerprintAttemptCount % 3 == 2 )
                        this.picAttempt2.BackgroundImage = reject.Image;
                    else
                    {
                        this.picAttempt3.BackgroundImage = reject.Image;
                        this.picAttempt1.BackgroundImage = empty.Image;
                    }
                    if( fingerprintAttemptCount == MAX_FINGERPRINT_ATTEMPTS )
                        EnvInfo.state = State.FINGERPRINT_FAILURE;
                    else
                        EnvInfo.state = State.FINGERPRINT_NOT_RECOGNIZED;
                    setState();
                });
            }
            return false;
        }

        #region EventHandler Members:

        public void OnComplete(object Capture, string ReaderSerialNumber, DPFP.Sample Sample)
        {
            MakeReport("The fingerprint sample was captured.");
            Process(Sample);
        }

        public void OnFingerGone(object Capture, string ReaderSerialNumber)
        {
            MakeReport("The finger was removed from the fingerprint reader.");
        }

        public void OnFingerTouch(object Capture, string ReaderSerialNumber)
        {
            MakeReport("The fingerprint reader was touched.");
        }

        public void OnReaderConnect(object Capture, string ReaderSerialNumber)
        {
            MakeReport("The fingerprint reader was connected.");
        }

        public void OnReaderDisconnect(object Capture, string ReaderSerialNumber)
        {
            MakeReport("The fingerprint reader was disconnected.");
        }

        public void OnSampleQuality(object Capture, string ReaderSerialNumber, DPFP.Capture.CaptureFeedback CaptureFeedback)
        {
            if (CaptureFeedback == DPFP.Capture.CaptureFeedback.Good)
                MakeReport("The quality of the fingerprint sample is good.");
            else
                MakeReport("The quality of the fingerprint sample is poor.");
        }
        #endregion

        private void tmrEnter_Tick(object sender, EventArgs e)
        {
            MakeReport("State: " + EnvInfo.state.ToString());
            if (EnvInfo.state != State.ID_CONFIRMED && EnvInfo.state != State.ID_NOT_RECOGNIZED
                    && EnvInfo.state != State.FINGERPRINT_NOT_RECOGNIZED && EnvInfo.state != State.FINGERPRINT_FAILURE 
                    && EnvInfo.state != State.NO_FINGERPRINTS_ON_FILE && EnvInfo.state != State.AWAITING_ID 
                    && EnvInfo.state != State.FINGERPRINT_OVERRIDE)
                return;
            this.BackColor = System.Drawing.Color.SteelBlue;
            if (EnvInfo.state == State.ID_CONFIRMED || EnvInfo.state == State.ID_NOT_RECOGNIZED
                || EnvInfo.state == State.FINGERPRINT_FAILURE || EnvInfo.state == State.NO_FINGERPRINTS_ON_FILE)
                EnvInfo.state = State.AWAITING_ID;
            else if (EnvInfo.state == State.FINGERPRINT_NOT_RECOGNIZED)
                EnvInfo.state = State.AWAITING_FINGERPRINT;
            setState();
            tmrEnter.Stop();
        }

        private void txtIdNumber_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter)
            {
                idSubmitted();
            }
        }

        private void webCamCapture1_ImageCaptured(object source, WebCam_Capture.WebcamEventArgs e)
        {
            if (EnvInfo.Camera == false)
                return;
            this.pictVideoStream.Image = e.WebCamImage;
            //this.pictBoxCamera.Image.
        }

        protected void SendOTWarningEmail()
        {
            try
            {
                System.Net.Mail.SmtpClient mailClient = new System.Net.Mail.SmtpClient();
                mailClient.UseDefaultCredentials = false;
                System.Net.ICredentialsByHost credentials = new System.Net.NetworkCredential("punchclock@msistaff.com", "Metro2017!");
                mailClient.Credentials = credentials;
                mailClient.DeliveryMethod = System.Net.Mail.SmtpDeliveryMethod.Network;
                mailClient.Host = "smtp.gmail.com";
                mailClient.Port = 587;
                mailClient.EnableSsl = false;
                //mailClient.EnableSsl = true;

                //The From address (Email ID)    
                string str_from_address = "punchclock@msistaff.com";
                //The Display Name    
                string str_name = "Overtime Warning!";
                //Create MailMessage Object    
                MailMessage email_msg = new MailMessage();
                //Specifying From,Sender & Reply to address    
                email_msg.From = new MailAddress(str_from_address, str_name);
                email_msg.Sender = new MailAddress(str_from_address, str_name);
                email_msg.ReplyToList.Add(new MailAddress(str_from_address, str_name));
                //The To Email id    
                foreach (string s in EnvInfo.OTWarningEmail)
                    email_msg.To.Add(s);
                email_msg.Subject = EmpInf.LastName + ", " + EmpInf.FirstName + " exceeds hour limits!";
                email_msg.Priority = MailPriority.High;
                //first we create the Plain Text part
                //AlternateView plainView = AlternateView.CreateAlternateViewFromString("This is my plain text content, viewable by those clients that don't support html", null, "text/plain");

                email_msg.Body = "<h1>" + DateTime.Now.ToString() + "</h1>";
                email_msg.Body += "<h1 style='color:red'>Overtime Warning!</h1>";
                email_msg.Body += "<h3>" + EmpInf.LastName + ", " + EmpInf.FirstName + "</h3>";
                email_msg.Body += "<h3>MSI #: " + EmpInf.IdNum + "</h3>";
                email_msg.Body += "<h3>Client: " + EnvInfo.ClientName + "</h3>";
                email_msg.Body += "<h3>Hours: " + CommunicationReturnInfo.hoursWorked;
                email_msg.IsBodyHtml = true;
                //Now Send the message    
                mailClient.Send(email_msg);
            }
            catch (Exception ex)
            {    //Some error occured    
                //MessageBox.Show(ex.Message.ToString());
            }
        }

//        protected void setDefaultDepartment()
//        {
//            EnvInfo.DepartmentButtons[0].Checked = true;
//        }
        protected void SendSwipeConfirmationEmail()
        {
            try
            {
                System.Net.Mail.SmtpClient mailClient = new System.Net.Mail.SmtpClient();
                mailClient.UseDefaultCredentials = false;
                System.Net.ICredentialsByHost credentials = new System.Net.NetworkCredential("punchclock@msistaff.com", "Metro2017!");
                mailClient.Credentials = credentials;
                mailClient.DeliveryMethod = System.Net.Mail.SmtpDeliveryMethod.Network;
                mailClient.Host = "smtp.gmail.com";
                mailClient.Port = 587;
                mailClient.EnableSsl = false;
                mailClient.EnableSsl = true;

                //The From address (Email ID)    
                string str_from_address = "punchclock@msistaff.com";
                //The Display Name    
                string str_name = "Punch Clock Record";
                //The To address (Email ID)    
                //Create MailMessage Object    
                MailMessage email_msg = new MailMessage();
                //Specifying From,Sender & Reply to address    
                email_msg.From = new MailAddress(str_from_address, str_name);
                email_msg.Sender = new MailAddress(str_from_address, str_name);
                email_msg.ReplyToList.Add(new MailAddress(str_from_address, str_name));
                //The To Email id    
                foreach(string s in EmpInf.Email)
                    email_msg.To.Add(s);
                email_msg.Subject = "Swipe Record";
                email_msg.Priority = MailPriority.Normal;
                //first we create the Plain Text part
                //AlternateView plainView = AlternateView.CreateAlternateViewFromString("This is my plain text content, viewable by those clients that don't support html", null, "text/plain");

                email_msg.Body = "\nMSI #" + EmpInf.IdNum + "\n" + EmpInf.FirstName + " " + EmpInf.LastName + "\n" + EmpInf.PunchDt.ToString("MM/dd/yyyy hh:mm:ss tt") + ".\n";
                email_msg.Body += "Client: " + EnvInfo.ClientName;
                email_msg.IsBodyHtml = false;
                //Now Send the message    
                mailClient.Send(email_msg);
            }
            catch (Exception ex)
            {    //Some error occured    
                //MessageBox.Show(ex.Message.ToString());
            }
        }

        protected void SendNotAuthorizedEmail(int reason)
        {
            try
            {
                System.Net.Mail.SmtpClient mailClient = new System.Net.Mail.SmtpClient();
                mailClient.UseDefaultCredentials = false;
                System.Net.ICredentialsByHost credentials = new System.Net.NetworkCredential("punchclock@msistaff.com", "Metro2017!");
                mailClient.Credentials = credentials;
                mailClient.DeliveryMethod = System.Net.Mail.SmtpDeliveryMethod.Network;
                mailClient.Host = "smtp.gmail.com";
                mailClient.Port = 587;
                mailClient.EnableSsl = false;
                mailClient.EnableSsl = true;

                //The From address (Email ID)    
                string str_from_address = "punchclock@msistaff.com";
                //The Display Name    
                string str_name = "Employee Not Authorized!";
                //Create MailMessage Object    
                MailMessage email_msg = new MailMessage();
                //Specifying From,Sender & Reply to address    
                email_msg.From = new MailAddress(str_from_address, str_name);
                email_msg.Sender = new MailAddress(str_from_address, str_name);
                email_msg.ReplyToList.Add(new MailAddress(str_from_address, str_name));
                //The To Email id    
                foreach (string s in EnvInfo.NotAuthorizedEmail)
                    email_msg.To.Add(s);
                email_msg.Subject = EmpInf.LastName + ", " + EmpInf.FirstName + " Not Authorized!!!";
                email_msg.Priority = MailPriority.High;
                //first we create the Plain Text part
                //AlternateView plainView = AlternateView.CreateAlternateViewFromString("This is my plain text content, viewable by those clients that don't support html", null, "text/plain");

                email_msg.Body = "<h1>" + DateTime.Now.ToString() + ", </h1>";
                email_msg.Body += "<h3>" + EmpInf.LastName + ", " + EmpInf.FirstName + "</h3>";
                email_msg.Body += "<h3>MSI #: " + EmpInf.IdNum + "</h3>";
                email_msg.Body += "<h3>Client: " + EnvInfo.ClientName + "</h3>";
                email_msg.IsBodyHtml = true;
                //Now Send the message    
                mailClient.Send(email_msg);
            }
            catch (Exception ex)
            {    //Some error occured    
                //MessageBox.Show(ex.Message.ToString());
            }
        }

        protected void SendBootUpEmail()
        {
            try
            {
                System.Net.Mail.SmtpClient mailClient = new System.Net.Mail.SmtpClient();
                mailClient.UseDefaultCredentials = false;
                System.Net.ICredentialsByHost credentials = new System.Net.NetworkCredential("punchclock@msistaff.com", "Metro2017!");
                mailClient.Credentials = credentials;
                mailClient.DeliveryMethod = System.Net.Mail.SmtpDeliveryMethod.Network;
                mailClient.Host = "mail.office365.com";
                mailClient.Port = 587;
                mailClient.EnableSsl = true;

                //The From address (Email ID)    
                string str_from_address = "punchclock@msistaff.com";
                //The Display Name    
                string str_name = "Fingerprint Entry System Bootup!";
                //Create MailMessage Object    
                MailMessage email_msg = new MailMessage();
                //Specifying From,Sender & Reply to address    
                email_msg.From = new MailAddress(str_from_address, str_name);
                email_msg.Sender = new MailAddress(str_from_address, str_name);
                email_msg.ReplyToList.Add(new MailAddress(str_from_address, str_name));
                //The To Email id    
                foreach (string s in EnvInfo.BootupEmail)
                    email_msg.To.Add(s);
                email_msg.Subject = EnvInfo.UserId[0] + " Booted up!";
                if (scheduledReboot == false)
                    email_msg.Subject = EnvInfo.UserId[0] + " - Unscheduled Entry System Reboot!";

                email_msg.Priority = MailPriority.High;
                //first we create the Plain Text part
                //AlternateView plainView = AlternateView.CreateAlternateViewFromString("This is my plain text content, viewable by those clients that don't support html", null, "text/plain");

                email_msg.Body = "<h1>At " + DateTime.Now.ToString() + ", </h1>";
                for( int i=0; i<EnvInfo.UserId.Count; i++ )
                {
                    email_msg.Body += EnvInfo.UserId[i] + "<br/>";
                }
                email_msg.Body += " booted up</h1>";
                email_msg.Body += startUpInfo;
                String[] punchFiles = Directory.GetFiles(EnvInfo.ImageDir, "_" + EnvInfo.CameraName + "__" + "*.jpg");
                if (punchFiles.Length == 0)
                    email_msg.Body += "<h2>No outstanding punches</h2>";
                else
                {
                    email_msg.Body += "<h2>Outstanding punches:</h2>";
                    for (int i = 0; i < punchFiles.Length; i++)
                    {
                        email_msg.Body += "<h3 style='margin_right:20px;'>" + punchFiles[i] + "</h3>";
                    }
                }
                email_msg.IsBodyHtml = true;
                //Now Send the message    
                mailClient.Send(email_msg);
            }
            catch (Exception ex)
            {
                //MessageBox.Show(ex.Message.ToString());
                Debug.WriteLine(ex);
            }
        }
        protected void SendHTMLEMail(string a, string htmlBody, string b)
        {
            Thread t = new Thread(SendHTMLEMailThread);
            t.Start(htmlBody);
        }
        protected void SendHTMLEMailThread(object htmlBody)
        {
            if (EnvInfo.Camera == false)
                return;
            try
            {
                //MemoryStream stream = new MemoryStream();
                //pictBoxEmailImage.Image.Save(stream, ImageFormat.Jpeg);
                //Thread.Sleep(20000);
                htmlBody = (string)htmlBody;
                System.Net.Mail.SmtpClient mailClient = new System.Net.Mail.SmtpClient();
                mailClient.UseDefaultCredentials = false;
                System.Net.ICredentialsByHost credentials = new System.Net.NetworkCredential("punchclock@msistaff.com", "Metro2017!");
                mailClient.Credentials = credentials;
                mailClient.DeliveryMethod = System.Net.Mail.SmtpDeliveryMethod.Network;
                mailClient.Host = "smtp.office365.com";
                mailClient.Port = 587;
                mailClient.EnableSsl = true;// false;
                //mailClient.EnableSsl = true;

                //The From address (Email ID)    
                string str_from_address = "punchclock@msistaff.com";
                //The Display Name    
                string str_name = "Fingerprint Check In";
                //Create MailMessage Object    
                MailMessage email_msg = new MailMessage();
                //Specifying From,Sender & Reply to address    
                email_msg.From = new MailAddress(str_from_address, str_name);
                email_msg.Sender = new MailAddress(str_from_address, str_name);
                email_msg.ReplyToList.Add(new MailAddress(str_from_address, str_name));
                //The To Email id    
                foreach (string s in EnvInfo.FingerprintFailedEmail)
                    email_msg.To.Add(s);
                email_msg.Subject = EmpInf.IdNum + " / " + EnvInfo.ClientName + " -- Failed to match Identity";
                email_msg.Priority = MailPriority.High;
                //first we create the Plain Text part
                //AlternateView plainView = AlternateView.CreateAlternateViewFromString("This is my plain text content, viewable by those clients that don't support html", null, "text/plain");

                string hc = "";// "<html>"; /* htmlContent */
                hc += "<table border=\"0\" bordercolor=\"#000000\" cellpadding=\"5\" cellspacing=\"0\" style=\"vertical-align: middle; width: 640px; text-align: left\"><tr><td bgcolor=\"#3344FF\" colspan=\"2\"><span style=\"font-size: 10pt; color: #ffffff; font-family: Arial\"><b>Metro Staff, Inc.</b></span></td></tr>";
                hc += "<tr><td colspan=\"2\"><span style=\"font-family: Arial Black\">Biometric Identity Verification Failed!</span></td></tr>";
                hc += "<tr>";
                hc += "<td><img width=\"320\" src=\"" + EnvInfo.ServerImages + EmpInf.PicName + "\" alt=\"if not visible, then the image folder has not yet synched or the image may be more than 60 days old.\"/></td>";
                hc += "<td>";
                hc += "<table width=\"320\" border=\"1\" bordercolor=\"LightBlue\">";
                hc += "<tr><td colspan=\"2\"><span style=\"font-size: 10pt; font-family: Arial\"><h1><b>" +
                        this.EmpInf.FirstName + " " + this.EmpInf.LastName + ", " + EmpInf.IdNum + "</b></h1></span></td></tr>";
                hc += "<tr><td bgcolor=\"#AAAAFF\" colspan=\"2\"><span style=\"color: #000000; font-family: Arial\">Metro Staff</span></td></tr>";
                hc += "<tr><td colspan=\"2\"><span style=\"font-size: 10pt; font-family: Arial\"><b>" +
                    EmpInf.PunchDt.ToString() + "</b></span></td></tr>";
                hc += "<tr><td bgcolor=\"#AAAAFF\" colspan=\"2\"><span style=\"font-size: 10pt; font-family: Arial\"><b>" + htmlBody + "</b></span></td></tr>";
                //hc += "<tr><td colspan=\"2\"><span style=\"font-size: 10pt; font-family: Arial\"><b>" + this.EmpInf.Dept + "</b></span></td></tr>";
                hc += "</table>";
                hc += "</td>";
                hc += "</tr>";
                hc += "<tr>";
                hc += "<td colspan=\"2\"><span style=\"font-family: Arial Black;\">" +
                    this.EmpInf.FirstName + " " + this.EmpInf.LastName + " - " + EmpInf.PunchDt +
                     "</td></tr>";
                hc += "</tr>";
                hc += "</table>";
                //hc = "<h1>Hello!</h1>";
                //hc += "</html>";

                email_msg.Body = hc;
                email_msg.IsBodyHtml = true;
                //Now Send the message    
                mailClient.SendAsync(email_msg, null);
            }
            catch (Exception ex)
            {    //Some error occured    
                //MessageBox.Show(ex.Message.ToString());
            }
        }

        private void btnSubmitId_Click(object sender, EventArgs e)
        {
            //Communication.SignInAsync();
            idSubmitted();
        }

        public void MakeReport(String s)
        {
            Debug.WriteLine(s);
            this.Invoke((MethodInvoker)delegate
            {
                lblReport.Text = s;
            });
        }

        /* update display clock, set focus every 5 ticks, and check if need to reboot */
        static int tickCounter = 0;
        private void tmrClock_Tick(object sender, EventArgs e)
        {
            lblDateTime.Text = DateTime.Now.ToString("MM/dd/yy hh:mm:ss");
            tickCounter++;
            if (tickCounter % 5 == 0)
            {
                this.TopMost = true;
                this.Activate();
                this.BringToFront();
                txtIdNumber.Focus();
            }
            /* should we reboot? */
            if( ((EnvInfo.RebootTime.Count > 0) && (DateTime.Now.Hour == EnvInfo.RebootTime[0].Hour && DateTime.Now.Minute == EnvInfo.RebootTime[0].Minute && DateTime.Now.Second < 20 ))
                || ((EnvInfo.RebootTime.Count > 1) && (DateTime.Now.Hour == EnvInfo.RebootTime[1].Hour && DateTime.Now.Minute == EnvInfo.RebootTime[1].Minute && DateTime.Now.Second < 20 )))
            {
                reboot();
            }
        }

        private void tmrAdmitDelay_Tick(object sender, EventArgs e)
        {
            /* no results in time from swipe to admission/rejection, 
             *  so send the person in, treat it like a fingerprint failure */
            tmrAdmitDelay.Stop();
            if (EnvInfo.state != State.FINGERPRINT_NOT_RECOGNIZED && EnvInfo.state != State.AWAITING_FINGERPRINT)
                return;
            EnvInfo.state = State.TIMEOUT_NO_FINGERPRINT;
            setState();
        }

        private void tmrKeepAlive_Tick(object sender, EventArgs e)
        {
            if (EnvInfo.Pulse == false)
                return;
            Communication.Pulse(this);
        }

        private void tmrClearPunches_Tick(object sender, EventArgs e)
        {
            if (EnvInfo.PunchInProgress >= 0 )  // SB > 0
                return;
             /* get next file that needs to be uploaded */
            string[] arr = Directory.GetFiles(EnvInfo.ImageDir, "_" + EnvInfo.CameraName + "__" + "*.*");
            if (arr.Length > 0)
            {
                Console.WriteLine("Archive size: " + arr.Length + ", " + DateTime.Now);
                bool imageNameOK = false;
                try
                {
                    string file = arr[0].Substring(arr[0].IndexOf("_" + EnvInfo.CameraName) + ("_" + EnvInfo.CameraName + "__").Length);
                    string id = file.Substring(0, file.IndexOf("__"));
                    if (id == null || id.Length == 0)
                    {
                        /* bad id for some reason...
                         * 
                         */
                        string name = arr[0].Substring(EnvInfo.ImageDir.Length);
                        string newName = "";
                        char[] charName = name.ToCharArray();
                        for( int i=0; i<name.Length; i++ )
                            if (charName[i] != '_')
                            {
                                newName += charName[i];
                            }
                            else
                            {
                                newName += "!";
                            }
                        File.Copy(arr[0], EnvInfo.ImageDir + "EXCEPTION__" + name);
                        File.Delete(arr[0]);
                        return;
                    }
                    string dateTime = file.Substring(file.IndexOf("__") + 2, file.IndexOf(".") - file.IndexOf("__") - 2);
                    int yr = Convert.ToInt32(dateTime.Substring(0, 4));
                    int mnth = Convert.ToInt32(dateTime.Substring(4, 2));
                    int day = Convert.ToInt32(dateTime.Substring(6, 2));
                    int hours = Convert.ToInt32(dateTime.Substring(9, 2));
                    int mins = Convert.ToInt32(dateTime.Substring(11, 2));
                    int secs = Convert.ToInt32(dateTime.Substring(13, 2));

                    DateTime dt = new DateTime(yr, mnth, day, hours, mins, secs);
                    imageNameOK = true;
                    bool result = Communication.SignInSavedData(this, dt.ToString(), id);

                    if (result)
                    {
                        if (EnvInfo.NoDropbox)
                        {
                            EmpInf.PicName = file;
                            EmpInf.Pic = (Bitmap)Image.FromFile(arr[0]);

                            MemoryStream stream = new MemoryStream();
                            EmpInf.Pic.Save(stream, ImageFormat.Jpeg);
                            EmpInf.PicData = stream.ToArray();

                            result = Communication.UploadPicture(this);

                            if (stream != null)
                                stream.Close();
                            if (EmpInf.Pic != null)
                                EmpInf.Pic.Dispose();
                            /* if pic was uploaded, delete the copy */
                            if (result == true)
                            {
                                File.Delete(arr[0]);
                                tmrClearPunches.Interval = 2500;  //check back in 30 secs.
                            }
                        }
                        else
                        {
                            File.Delete(arr[0]);
                            tmrClearPunches.Interval = 2500;  //check back in 30 secs.
                        }
                    }
                    else
                    {
                        tmrClearPunches.Interval = 1000 * 60 * 20;  //didn't go through, no internet?  try in 2 minutes
                    }
                }
                catch (Exception ex)
                {
                    if (!imageNameOK)
                    {
                        string name = arr[0].Substring(EnvInfo.ImageDir.Length);
                        File.Copy(arr[0], EnvInfo.ImageDir + "EXCEPTION__" + name);
                        File.Delete(arr[0]);
                    }
                }
            }
            else
            {
                tmrClearPunches.Interval = 300000; // nothing to do, check back in 5 minutes
            }
        }

        private void pictFingerprint1_Click(object sender, EventArgs e)
        {
        }

        private void rbDept1_CheckedChanged(object sender, EventArgs e)
        {
            txtIdNumber.Focus();
        }
        private void rbDept2_CheckedChanged(object sender, EventArgs e)
        {
            txtIdNumber.Focus();
        }
        private void rbDept3_CheckedChanged(object sender, EventArgs e)
        {
            txtIdNumber.Focus();
        }
        private void rbDept4_CheckedChanged(object sender, EventArgs e)
        {
            txtIdNumber.Focus();
        }

        private void rbDefaultDept_CheckedChanged(object sender, EventArgs e)
        {
            txtIdNumber.Focus();
        }

        private void rbDept2_CheckedChanged_1(object sender, EventArgs e)
        {
            txtIdNumber.Focus();
        }

        private void rbDept3_CheckedChanged_1(object sender, EventArgs e)
        {
            txtIdNumber.Focus();
        }

        private void rbDept4_CheckedChanged_1(object sender, EventArgs e)
        {
            txtIdNumber.Focus();
        }

        private void txtIdNumber_TextChanged(object sender, EventArgs e)
        {

        }

        /*        private void EntryForm_MouseDoubleClick(object sender, MouseEventArgs e)
                {
                    Form form = (Form)sender;
                    Control[] lbl = form.Controls.Find("lblDepartmentName", false);
                    //MessageBox.Show(((Label)lbl[0]).ForeColor.ToString());
                    MessageBox.Show(((Label)lbl[0]).Enabled.ToString());
                } */
    }
}

