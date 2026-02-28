using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Drawing;
using System.Windows.Forms;

namespace FingerprintVerification
{
    public enum State
    {
        AWAITING_ID, AWAITING_FINGERPRINT, FINGERPRINT_OVERRIDE, ID_CONFIRMED,
        ID_NOT_RECOGNIZED, LOADING_EMPLOYEE_DATA, FINGERPRINT_NOT_RECOGNIZED, FINGERPRINT_FAILURE,
        NO_FINGERPRINTS_ON_FILE, TIMEOUT_NO_FINGERPRINT
    }; 

    public class EnvironmentInfo
    {
        public List<String> DepartmentNames { get; set; }
        public List<int> DepartmentIDs { get; set; }
        public List<RadioButton> DepartmentButtons { get; set; }

        public int DepartmentID { get; set; }
        public String DepartmentName { get; set; }

        public int PunchInProgress { get; set; }
        public string BuildDate { get; set; }  /* to check version currently running */
        /* Environment variables */
        public List<string> UserId { get; set; }
        public List<string> Password { get; set; }  /* userid / password for punch submit */
        public List<DateTime> RebootTime { get; set; } /* times that the computer should reboot */

        public int NameSize { get; set; }   /* number of characters in name displayed */
        public Image PlaceHolderImage { get; set; } /* if no camera, use this to hold failed punch info */
        public string CameraName { get; set; }
        public int Timeout { get; set; }   /* time before giving up on getting a fingerprint */
        public List<string> FingerprintFailedEmail { get; set; }     /* where to send the email to */
        public List<string> NotAuthorizedEmail { get; set; }  /* email for notifying employee is not authorized */
        public List<string> OTWarningEmail { get; set; }  /* email sent if 38 hours or more at check-in */
        public List<string> BootupEmail { get; set; }  /* email sent if 38 hours or more at check-in */
        public string ClientName { get; set; }       /* generally the Client Name, but different for combined clients */
        public bool Fingerprints { get; set; } /* are we taking fingerprints or not? */
        public bool Camera { get; set; }
        public string Homedrive { get; set; }
        /* are different swipes going to different clients? (UserId.Count > 1) */
        public Boolean MultipleClients { get; set; }
        public string ImageDir { get; set; }
        public string Dir { get; set; }
        public string ImageName { get; set; }
        public string ServerImages { get; set; }
        public string ShiftData { get; set; }
        public bool Pulse { get; set; }
        public bool NoDropbox { get; set; }
        public bool ReportHours { get; set; }
        public int OTHoursLimit { get; set; }
        public bool LEDDisplay { get; set; }
        public bool SendBootupEmail { get; set; }
        public bool SmallScreen { get; set; }
        public State state;
    }
}
