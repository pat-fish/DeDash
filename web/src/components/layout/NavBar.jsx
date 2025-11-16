"use client";

import Logo from "./Logo";
import Loc from "./Loc";
import SearchBar from "./SearchBar";
import ProfileButton from "./ProfileButton";

export default function NavBar( {onProfileClick} ) {
    return (
        <div className="flex justify-between items-center px-6 py-4 bg-silver">
            <div className="flex items-center gap-4">
                <Logo />
                <Loc />
            </div>
            <div className="flex items-center gap-4">
                <SearchBar />
                <ProfileButton onClick={onProfileClick} />
            </div>
        </div>
    );
}
