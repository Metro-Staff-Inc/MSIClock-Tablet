using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Collections.Generic;

namespace FingerprintVerification
{
    public class EmployeeInfo
    {
        private String                  _idNum;
        private List<DPFP.Template>     _template = null;
        private String          _lastName;
        private String          _firstName;
        private Bitmap          _pic;
        private String          _shift;
        private String          _picName;
        private byte[]          _picData;
        private String          _dept;
        private int             _fptLevel;
        private DateTime        _punchDt;
        private int             _clientIdx;

        public List<String> Email { get; set; }

        public DateTime PunchDt
        {
            get
            {
                return _punchDt;
            }
            set
            {
                _punchDt = value;
            }
        }

        public byte[] PicData
        {
            get
            {
                return _picData;
            }
            set
            {
                _picData = value;
            }  
        }
        public String Shift
        {
            get
            {
                return _shift;
            }
            set
            {
                _shift = value;
            }
        }
        public String Dept
        {
            get
            {
                return _dept;
            }
            set
            {
                _dept = value;
            }
        }
        public String PicName
        {
            get{ return _picName; }
            set { _picName = value; }
        }
        public String IdNum
        {
            get
            {
                return _idNum;
            }
            set
            {
                _idNum = value;
            }
        }
        public List<DPFP.Template> Template
        {
            get
            {
                return _template;
            }
            set
            {
                _template = value;
            }
        }
        public String FirstName
        {
            get
            {
                return _firstName;
            }
            set
            {
                _firstName = value;
            }
        }
        public String LastName
        {
            get
            {
                return _lastName;
            }
            set
            {
                _lastName = value;
            }
        }
        public Bitmap Pic
        {
            get
            {
                return _pic;
            }
            set
            {
                _pic = value;
            }
        }
        public int FptLevel
        {
            get
            {
                return _fptLevel;
            }
            set
            {
                _fptLevel = value;
            }
        }
    }
}
